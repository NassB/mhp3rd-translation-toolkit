// Moteur de pré-traduction d'un fichier (docs/DECISIONS/0006-pretraduction-ia.md).
//
// Règles : résultats **toujours en `draft`**, jamais d'écrasement d'une
// traduction `translated`/`reviewed`/`locked` ; chaque résultat est contrôlé
// (linter, termes obligatoires, octets) avec **un seul** nouvel essai ; une
// chaîne en échec est laissée intacte. Le rapport ne contient aucun texte du
// jeu : seulement des identifiants, des compteurs et des raisons.
//
// Budget d'octets (TA4b, ARCHITECTURE.md §8.2) : le fichier reconstruit doit
// rester <= l'original. Un fichier non traduit a exactement la taille de
// l'original, donc ce budget équivaut à « somme des écarts `octets(traduction)
// - octets(source)` <= 0 » sur les chaînes traduites. Le moteur suit cette
// somme (« enveloppe du fichier »), laisse chaque chaîne dépasser sa source
// dans une limite large, puis **raccourcit** les plus gourmandes si le total
// dépasse. Les brouillons n'entrent pas dans un build : un dépassement final
// est signalé, jamais caché.

import 'dart:convert';
import 'dart:math' as math;

import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'batching.dart';
import 'chat_client.dart';
import 'prompt.dart';
import 'response_parser.dart';

/// Jeton d'annulation coopérative (vérifié entre deux lots).
final class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Pourquoi une traduction proposée a été refusée.
enum FailureReason {
  /// Absente (ou vide) dans la réponse du modèle.
  missing,

  /// Nombre de sauts de ligne différent de la source.
  newlineCount,

  /// Contient un octet NUL.
  nulChar,

  /// Terme obligatoire du glossaire absent.
  mandatoryTerm,

  /// Dépasse la limite d'octets de la chaîne.
  overBudget,
}

/// Une chaîne laissée intacte.
final class FailedUnit {
  /// Voir les champs.
  FailedUnit(this.sourceId, Set<FailureReason> reasons)
      : reasons = Set.unmodifiable(reasons);

  final int sourceId;
  final Set<FailureReason> reasons;
}

/// Avancement après chaque lot.
final class PreTranslateProgress {
  /// Voir les champs.
  const PreTranslateProgress({
    required this.processed,
    required this.total,
    required this.saved,
    required this.failed,
  });

  /// Chaînes déjà traitées (enregistrées, en échec ou en conflit).
  final int processed;

  /// Chaînes à traiter au total.
  final int total;
  final int saved;
  final int failed;
}

/// Réglages de [preTranslateFile].
final class PreTranslateOptions {
  /// Voir les champs.
  const PreTranslateOptions({
    this.includeDrafts = false,
    this.maxUnits = 40,
    this.maxBatchTokens = 3000,
    this.fixedPromptTokens = 350,
    this.tokensPerEstimate = 1.0,
    this.contextSize = 3,
    this.contextChars = 160,
    this.perStringFactor = 2.5,
    this.minMaxBytes = 24,
    this.enforceFileBudget = true,
    this.shortenFloorBytes = 16,
    this.limit,
    this.temperature = 0.2,
    this.prompt = const PromptOptions(),
  });

  /// Retraduire aussi les chaînes déjà en `draft` (jamais `translated` ou
  /// plus).
  final bool includeDrafts;

  /// Plafonds d'un lot (voir `buildBatches`).
  final int maxUnits;
  final int maxBatchTokens;

  /// Jetons fixes du prompt (consigne, schéma) retirés du plafond d'un lot :
  /// mesurés à ≈ 300 sur LM Studio.
  final int fixedPromptTokens;
  final double tokensPerEstimate;

  /// Nombre de chaînes voisines envoyées avant et après un lot, et longueur
  /// maximale de chacune.
  final int contextSize;
  final int contextChars;

  /// Nombre maximal de chaînes traitées (les premières du fichier) ; `null` :
  /// toutes.
  final int? limit;

  /// Limite d'octets d'une chaîne : `max(minMaxBytes, octets(source) ×
  /// perStringFactor)`. Large à dessein : le vrai garde-fou est l'enveloppe du
  /// fichier. Une source courte japonaise (3 octets par caractère) donne
  /// souvent une traduction latine plus longue sans dépasser le fichier.
  final double perStringFactor;
  final int minMaxBytes;

  /// Si le total du fichier dépasse son original après la traduction, redemande
  /// des versions plus courtes des chaînes qui grandissent le plus.
  final bool enforceFileBudget;

  /// Limite visée pour une chaîne qu'on raccourcit : `max(octets(source),
  /// shortenFloorBytes)`.
  final int shortenFloorBytes;
  final double temperature;
  final PromptOptions prompt;
}

/// Résultat d'une exécution. Aucun texte du jeu.
final class PreTranslateReport {
  /// Voir les champs.
  PreTranslateReport({
    required this.candidates,
    required this.saved,
    required List<FailedUnit> failed,
    required this.conflicts,
    required this.skippedNoJapanese,
    required this.skippedEmpty,
    required this.warnings,
    required this.batches,
    required this.promptTokens,
    required this.completionTokens,
    required this.cancelled,
    required this.stoppedBy,
    required this.unprocessed,
    required this.startDeltaBytes,
    required this.endDeltaBytes,
    required this.shortened,
  }) : failed = List.unmodifiable(failed);

  /// Chaînes retenues pour la traduction.
  final int candidates;
  final int saved;
  final List<FailedUnit> failed;

  /// Enregistrements refusés car la ligne avait changé entre-temps.
  final int conflicts;

  /// Chaînes sans japonais (laissées telles quelles) et chaînes vides.
  final int skippedNoJapanese;
  final int skippedEmpty;

  /// Constats non bloquants acceptés (espaces de bord, terme suggéré).
  final int warnings;
  final int batches;
  final int promptTokens;
  final int completionTokens;
  final bool cancelled;

  /// Erreur du fournisseur qui a arrêté l'exécution (serveur absent…).
  final TranslateError? stoppedBy;

  /// Chaînes retenues mais non traitées (annulation ou arrêt).
  final int unprocessed;

  /// Somme des écarts `octets(traduction) - octets(source)` du fichier avant
  /// et après l'exécution (négatif : marge disponible).
  final int startDeltaBytes;
  final int endDeltaBytes;

  /// Chaînes réécrites plus courtes pour respecter l'enveloppe du fichier.
  final int shortened;

  /// Octets dont le fichier dépasserait son original (0 : dans le budget).
  int get overBudgetBytes => endDeltaBytes > 0 ? endDeltaBytes : 0;

  /// Le fichier tient dans son budget d'octets.
  bool get withinBudget => endDeltaBytes <= 0;

  /// Vrai si tout ce qui était retenu a été traité sans échec et dans le
  /// budget.
  bool get clean =>
      !cancelled &&
      stoppedBy == null &&
      failed.isEmpty &&
      conflicts == 0 &&
      unprocessed == 0 &&
      withinBudget;
}

final _japanese = RegExp(r'[぀-ヿ㐀-鿿]');

int _bytes(String s) => utf8.encode(s).length;

/// Retire les espaces de bord que la source n'a pas.
String _normalize(String source, String text) {
  var t = text;
  if (!RegExp(r'^\s').hasMatch(source)) t = t.trimLeft();
  if (!RegExp(r'\s$').hasMatch(source)) t = t.trimRight();
  return t;
}

class _Check {
  _Check(this.reasons, this.hints, this.warnings);

  final Set<FailureReason> reasons;
  final List<String> hints;
  final int warnings;
}

_Check _validate(
  String source,
  String text,
  int maxBytes,
  List<GlossaryEntry> glossary,
) {
  final reasons = <FailureReason>{};
  final hints = <String>[];
  var warnings = 0;
  final issues = lintTranslation(
    source: source,
    target: text,
    glossary: glossary,
  );
  final wantNl = '\n'.allMatches(source).length;
  for (final i in issues) {
    switch (i.kind) {
      case LintKind.emptyTranslation:
        reasons.add(FailureReason.missing);
        hints.add('la traduction est vide');
      case LintKind.newlineCount:
        reasons.add(FailureReason.newlineCount);
        hints.add('le texte doit contenir exactement $wantNl saut(s) de ligne');
      case LintKind.nulChar:
        reasons.add(FailureReason.nulChar);
        hints.add('supprime le caractère NUL');
      case LintKind.mandatoryTerm:
        reasons.add(FailureReason.mandatoryTerm);
        hints.add('emploie le terme obligatoire « ${i.detail} »');
      case LintKind.edgeWhitespace:
      case LintKind.suggestedTerm:
      case LintKind.frenchSpacing:
        warnings++;
    }
  }
  final size = _bytes(text);
  if (size > maxBytes) {
    reasons.add(FailureReason.overBudget);
    hints.add('trop long ($size octets, maximum $maxBytes) : raccourcis');
  }
  return _Check(reasons, hints, warnings);
}

/// Écart d'octets d'une chaîne traduite par rapport à sa source.
int _delta(SlotView s, String text) => _bytes(text) - _bytes(s.sourceText);

/// Somme des écarts des traductions existantes (hors `untranslated`) et
/// contribution de chaque chaîne.
({int total, Map<int, int> perString}) _currentDelta(List<SlotView> slots) {
  final per = <int, int>{};
  var total = 0;
  for (final s in slots) {
    final t = s.translation;
    if (s.isAlias || t == null || t.status == 'untranslated') continue;
    final d = _delta(s, t.text);
    per[s.sourceId] = d;
    total += d;
  }
  return (total: total, perString: per);
}

/// Une chaîne enregistrée pendant cette exécution.
class _Saved {
  _Saved(this.unit, this.text, this.revision);

  final TranslationUnit unit;
  String text;
  int revision;
}

/// Pré-traduit les chaînes du fichier [fileId] et les enregistre en `draft`.
///
/// Sélection : chaînes non alias, non vides, contenant du japonais, sans
/// traduction (ou en `draft` si [PreTranslateOptions.includeDrafts]). Relancer
/// la fonction ne retraduit donc pas ce qui l'est déjà. [model] sert aussi de
/// provenance (`ai:<model>`) dans `author_id`.
Future<PreTranslateReport> preTranslateFile({
  required TranslationRepository repo,
  required GlossaryRepository glossary,
  required ChatClient client,
  required String model,
  required int fileId,
  PreTranslateOptions options = const PreTranslateOptions(),
  CancelToken? cancel,
  void Function(PreTranslateProgress progress)? onProgress,
}) async {
  final slots = await repo.slots(fileId, limit: await repo.countSlots(fileId));
  final entries = [
    for (final t in await glossary.all())
      GlossaryEntry(
        sourceTerm: t.sourceTerm,
        targetTerm: t.targetTerm,
        mandatory: t.mandatory,
      ),
  ];

  final plan = _select(slots, options);
  final units = plan.units;
  final indexById = plan.indexById;
  final batches = plan.batches;
  final startDelta = _currentDelta(slots);
  var delta = startDelta.total;
  final contribution = {...startDelta.perString};
  final savedNow = <int, _Saved>{};

  var saved = 0;
  var conflicts = 0;
  var warnings = 0;
  var promptTokens = 0;
  var completionTokens = 0;
  var done = 0;
  var batchCount = 0;
  var shortened = 0;
  var cancelled = false;
  TranslateError? stoppedBy;
  final failed = <FailedUnit>[];

  List<String> neighbours(int from, int step) {
    final out = <String>[];
    for (var i = from;
        i >= 0 && i < slots.length && out.length < options.contextSize;
        i += step) {
      final s = slots[i].sourceText.trim();
      if (s.isEmpty) continue;
      out.add(
        s.length > options.contextChars
            ? s.substring(0, options.contextChars)
            : s,
      );
    }
    return step < 0 ? out.reversed.toList() : out;
  }

  /// Un appel au modèle ; retourne les traductions reçues (peut être vide).
  Future<Map<int, String>> ask(
    Batch batch,
    BatchContext ctx, {
    int tokenFactor = 1,
  }) async {
    batchCount++;
    final out = (batch.units.length * 60 + 300) * tokenFactor;
    try {
      final r = await client.chat(
        model: model,
        messages: buildMessages(batch, options: options.prompt, context: ctx),
        temperature: options.temperature,
        maxTokens: out.clamp(512, 12000),
        jsonSchema: translationSchema(),
      );
      promptTokens += r.promptTokens ?? 0;
      completionTokens += r.completionTokens ?? 0;
      return parseTranslations(r.content, batch).translations;
    } on TranslateError catch (e) {
      switch (e.kind) {
        case TranslateErrorKind.invalidResponse:
        case TranslateErrorKind.emptyResponse:
        case TranslateErrorKind.truncated:
          return const {}; // lot traité comme « rien reçu » : nouvel essai
        case TranslateErrorKind.unreachable:
        case TranslateErrorKind.timeout:
        case TranslateErrorKind.http:
          rethrow;
      }
    }
  }

  for (final batch in batches) {
    if (cancel?.isCancelled ?? false) {
      cancelled = true;
      break;
    }
    try {
      final first = indexById[batch.units.first.id]!;
      final last = indexById[batch.units.last.id]!;
      final ctx = BatchContext(
        before: neighbours(first - 1, -1),
        after: neighbours(last + 1, 1),
        glossary: entries,
      );
      final accepted = <int, String>{};
      final reasons = <int, Set<FailureReason>>{};
      final hints = <int, List<String>>{};

      void judge(Map<int, String> got, Iterable<TranslationUnit> asked) {
        for (final u in asked) {
          final raw = got[u.id];
          if (raw == null) {
            reasons[u.id] = {FailureReason.missing};
            hints[u.id] = ['traduction manquante'];
            continue;
          }
          final text = _normalize(u.source, raw);
          final c = _validate(u.source, text, u.maxBytes, entries);
          if (c.reasons.isEmpty) {
            accepted[u.id] = text;
            reasons.remove(u.id);
            warnings += c.warnings;
          } else {
            reasons[u.id] = c.reasons;
            hints[u.id] = c.hints;
          }
        }
      }

      judge(await ask(batch, ctx), batch.units);
      if (reasons.isNotEmpty) {
        final retryUnits = [
          for (final u in batch.units)
            if (reasons.containsKey(u.id)) u,
        ];
        final retryCtx = BatchContext(
          before: ctx.before,
          after: ctx.after,
          glossary: ctx.glossary,
          corrections: {
            for (final u in retryUnits) u.id: hints[u.id]!.join(' ; '),
          },
        );
        judge(
          await ask(Batch(retryUnits, 0), retryCtx, tokenFactor: 2),
          retryUnits,
        );
      }

      for (final u in batch.units) {
        final text = accepted[u.id];
        if (text == null) {
          failed.add(
            FailedUnit(u.id, reasons[u.id] ?? {FailureReason.missing}),
          );
          continue;
        }
        final slot = slots[indexById[u.id]!];
        final result = await repo.saveTranslation(
          sourceId: u.id,
          text: text,
          status: 'draft',
          expectedRevision: slot.translation?.revision,
          authorId: 'ai:$model',
        );
        if (result is SaveOk) {
          saved++;
          final d = _delta(slot, text);
          delta += d - (contribution[u.id] ?? 0);
          contribution[u.id] = d;
          savedNow[u.id] = _Saved(u, text, result.translation.revision);
        } else {
          conflicts++;
        }
      }
      done += batch.units.length;
      onProgress?.call(
        PreTranslateProgress(
          processed: done,
          total: units.length,
          saved: saved,
          failed: failed.length,
        ),
      );
    } on TranslateError catch (e) {
      stoppedBy = e;
      break;
    }
  }

  // Enveloppe du fichier : si le total dépasse l'original, redemander des
  // versions plus courtes des chaînes qui grandissent le plus.
  if (!cancelled &&
      stoppedBy == null &&
      options.enforceFileBudget &&
      delta > 0) {
    final growth = [
      for (final s in savedNow.values)
        if (_bytes(s.text) > _bytes(s.unit.source)) s,
    ]..sort(
        (a, b) => (_bytes(b.text) - _bytes(b.unit.source)).compareTo(
          _bytes(a.text) - _bytes(a.unit.source),
        ),
      );
    for (var i = 0; i < growth.length && delta > 0; i += options.maxUnits) {
      if (cancel?.isCancelled ?? false) {
        cancelled = true;
        break;
      }
      final chunk = growth.sublist(
        i,
        math.min(i + options.maxUnits, growth.length),
      );
      final asked = [
        for (final s in chunk)
          TranslationUnit(
            id: s.unit.id,
            source: s.unit.source,
            maxBytes:
                math.max(_bytes(s.unit.source), options.shortenFloorBytes),
          ),
      ];
      try {
        final got = await ask(
          Batch(asked, 0),
          BatchContext(
            glossary: entries,
            corrections: {
              for (final u in asked)
                u.id: 'trop long pour le budget d’octets du fichier : '
                    '${_bytes(savedNow[u.id]!.text)} octets, '
                    'vise ${u.maxBytes} octets au maximum',
            },
          ),
        );
        for (final u in asked) {
          if (delta <= 0) break;
          final raw = got[u.id];
          if (raw == null) continue;
          final text = _normalize(u.source, raw);
          final current = savedNow[u.id]!;
          final c = _validate(u.source, text, u.maxBytes, entries);
          if (c.reasons.isNotEmpty || _bytes(text) >= _bytes(current.text)) {
            continue;
          }
          final slot = slots[indexById[u.id]!];
          final result = await repo.saveTranslation(
            sourceId: u.id,
            text: text,
            status: 'draft',
            expectedRevision: current.revision,
            authorId: 'ai:$model',
          );
          if (result is SaveOk) {
            final d = _delta(slot, text);
            delta += d - (contribution[u.id] ?? 0);
            contribution[u.id] = d;
            current
              ..text = text
              ..revision = result.translation.revision;
            shortened++;
          } else {
            conflicts++;
          }
        }
      } on TranslateError catch (e) {
        stoppedBy = e;
        break;
      }
    }
  }

  return PreTranslateReport(
    candidates: units.length,
    saved: saved,
    failed: failed,
    conflicts: conflicts,
    skippedNoJapanese: plan.skippedNoJapanese,
    skippedEmpty: plan.skippedEmpty,
    warnings: warnings,
    batches: batchCount,
    promptTokens: promptTokens,
    completionTokens: completionTokens,
    cancelled: cancelled,
    stoppedBy: stoppedBy,
    unprocessed: units.length - done,
    startDeltaBytes: startDelta.total,
    endDeltaBytes: delta,
    shortened: shortened,
  );
}

class _Selection {
  _Selection(
    this.units,
    this.indexById,
    this.batches,
    this.skippedEmpty,
    this.skippedNoJapanese,
  );

  final List<TranslationUnit> units;
  final Map<int, int> indexById;
  final List<Batch> batches;
  final int skippedEmpty;
  final int skippedNoJapanese;
}

/// Choisit les chaînes à traduire et les découpe en lots.
_Selection _select(List<SlotView> slots, PreTranslateOptions options) {
  var skippedEmpty = 0;
  var skippedNoJapanese = 0;
  final units = <TranslationUnit>[];
  final indexById = <int, int>{};
  for (var i = 0; i < slots.length; i++) {
    final s = slots[i];
    indexById[s.sourceId] = i;
    if (s.isAlias) continue;
    if (options.limit != null && units.length >= options.limit!) continue;
    final t = s.translation;
    final todo = t == null ||
        t.status == 'untranslated' ||
        (options.includeDrafts && t.status == 'draft');
    if (!todo) continue;
    if (s.sourceText.trim().isEmpty) {
      skippedEmpty++;
      continue;
    }
    if (!_japanese.hasMatch(s.sourceText)) {
      skippedNoJapanese++;
      continue;
    }
    final cap = (_bytes(s.sourceText) * options.perStringFactor).ceil();
    units.add(
      TranslationUnit(
        id: s.sourceId,
        source: s.sourceText,
        maxBytes: math.max(options.minMaxBytes, cap),
      ),
    );
  }
  final batches = buildBatches(
    units,
    maxUnits: options.maxUnits,
    maxBatchTokens: (options.maxBatchTokens - options.fixedPromptTokens).clamp(
      200,
      1 << 30,
    ),
    tokensPerEstimate: options.tokensPerEstimate,
  );
  return _Selection(units, indexById, batches, skippedEmpty, skippedNoJapanese);
}

/// Ce que [preTranslateFile] ferait, **sans rien envoyer** (`--dry-run`).
final class PreTranslatePlan {
  /// Voir les champs.
  const PreTranslatePlan({
    required this.candidates,
    required this.batches,
    required this.skippedEmpty,
    required this.skippedNoJapanese,
    required this.estimatedPromptTokens,
    required this.budgetMarginBytes,
  });

  final int candidates;
  final int batches;
  final int skippedEmpty;
  final int skippedNoJapanese;

  /// Estimation (prudente) des jetons envoyés au total, consigne comprise.
  final int estimatedPromptTokens;

  /// Marge d'octets restante du fichier avec les traductions actuelles
  /// (négative : déjà au-dessus de l'original).
  final int budgetMarginBytes;
}

/// Calcule le [PreTranslatePlan] du fichier [fileId] : aucune requête n'est
/// faite, rien n'est écrit.
Future<PreTranslatePlan> planPreTranslation({
  required TranslationRepository repo,
  required int fileId,
  PreTranslateOptions options = const PreTranslateOptions(),
}) async {
  final slots = await repo.slots(fileId, limit: await repo.countSlots(fileId));
  final plan = _select(slots, options);
  return PreTranslatePlan(
    candidates: plan.units.length,
    batches: plan.batches.length,
    skippedEmpty: plan.skippedEmpty,
    skippedNoJapanese: plan.skippedNoJapanese,
    estimatedPromptTokens: plan.batches.fold<int>(
      0,
      (a, b) => a + b.estimatedTokens + options.fixedPromptTokens,
    ),
    budgetMarginBytes: -_currentDelta(slots).total,
  );
}
