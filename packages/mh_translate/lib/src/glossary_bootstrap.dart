// Amorçage du glossaire (TA8, docs/DECISIONS/0006-pretraduction-ia.md).
//
// L'humain ne lit pas le japonais : il ne peut pas constituer seul la liste des
// noms (monstres, objets, lieux). On extrait des **termes candidats** (suites
// de katakana ou de kanji fréquentes dans les sources) et on demande au modèle
// une traduction **proposée**. Rien n'est jamais ajouté au glossaire sans
// validation humaine : ce fichier ne touche pas à la base.
//
// Les messages contiennent du texte du jeu : envoyés au seul serveur choisi,
// jamais journalisés ni affichés dans une erreur.

import 'dart:convert';

import 'package:mh_tdb/mh_tdb.dart';

import 'chat_client.dart';
import 'response_parser.dart';

/// Un terme source candidat.
final class TermCandidate {
  /// Voir les champs.
  const TermCandidate({
    required this.term,
    required this.count,
    required this.example,
  });

  /// Suite de katakana ou de kanji.
  final String term;

  /// Nombre de chaînes sources qui le contiennent.
  final int count;

  /// Première chaîne source qui le contient (contexte pour le modèle).
  final String example;
}

bool _isKatakana(int c) =>
    (c >= 0x30A1 && c <= 0x30FA) || c == 0x30FC || c == 0x30FB;

bool _isKanji(int c) => (c >= 0x4E00 && c <= 0x9FFF) || c == 0x3005; // 々

/// Suites maximales de katakana (≥ [minKatakana] points de code) ou de kanji
/// (≥ [minKanji]) de [text], sans doublon.
Set<String> termRuns(
  String text, {
  int minKatakana = 3,
  int minKanji = 2,
  int maxLength = 16,
}) {
  final out = <String>{};
  final run = <int>[];
  bool? kata;

  void flush() {
    final min = kata == true ? minKatakana : minKanji;
    if (run.length >= min && run.length <= maxLength) {
      out.add(String.fromCharCodes(run));
    }
    run.clear();
  }

  for (final c in text.runes) {
    final k = _isKatakana(c);
    final j = _isKanji(c);
    if (!k && !j) {
      flush();
      kata = null;
      continue;
    }
    if (run.isNotEmpty && kata != k) flush();
    // « ー » et « ・ » seuls ne commencent pas une suite.
    if (run.isEmpty && (c == 0x30FC || c == 0x30FB)) continue;
    kata = k;
    run.add(c);
  }
  flush();
  return out;
}

/// Termes candidats de [sources] (une entrée = une chaîne source), présents
/// dans au moins [minCount] chaînes et absents de [known]. Triés par
/// fréquence × longueur décroissante, puis alphabétiquement ; au plus [limit].
List<TermCandidate> extractTermCandidates(
  Iterable<String> sources, {
  Set<String> known = const {},
  int minCount = 3,
  int limit = 100,
  int minKatakana = 3,
  int minKanji = 2,
}) {
  final counts = <String, int>{};
  final examples = <String, String>{};
  for (final s in sources) {
    for (final t in termRuns(
      s,
      minKatakana: minKatakana,
      minKanji: minKanji,
    )) {
      counts[t] = (counts[t] ?? 0) + 1;
      examples.putIfAbsent(t, () => s);
    }
  }
  final all = [
    for (final e in counts.entries)
      if (e.value >= minCount && !known.contains(e.key))
        TermCandidate(term: e.key, count: e.value, example: examples[e.key]!),
  ]..sort((a, b) {
      final byScore =
          (b.count * b.term.runes.length) - (a.count * a.term.runes.length);
      return byScore != 0 ? byScore : a.term.compareTo(b.term);
    });
  return all.length > limit ? all.sublist(0, limit) : all;
}

/// Termes candidats de tout le projet : chaînes non alias de tous les fichiers
/// importés, hors termes déjà présents dans le glossaire.
Future<List<TermCandidate>> projectTermCandidates({
  required TranslationRepository repo,
  required GlossaryRepository glossary,
  int minCount = 3,
  int limit = 100,
}) async {
  final known = {for (final t in await glossary.all()) t.sourceTerm};
  final texts = <String>[];
  for (final f in await repo.listFiles()) {
    final n = await repo.countSlots(f.id);
    for (final s in await repo.slots(f.id, limit: n)) {
      if (!s.isAlias && s.sourceText.isNotEmpty) texts.add(s.sourceText);
    }
  }
  return extractTermCandidates(
    texts,
    known: known,
    minCount: minCount,
    limit: limit,
  );
}

/// Schéma JSON de la réponse : une traduction par terme.
JsonSchemaFormat termSchema() => const JsonSchemaFormat(
      name: 'glossary_terms',
      schema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
                'translation': {'type': 'string'},
              },
              'required': ['id', 'translation'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      },
    );

/// Longueur maximale d'une chaîne d'exemple envoyée au modèle.
const int _maxExampleRunes = 120;

String _clip(String s) {
  final r = s.runes.toList();
  return r.length <= _maxExampleRunes
      ? s
      : String.fromCharCodes(r.take(_maxExampleRunes));
}

/// Messages demandant une traduction pour chaque terme de [batch].
List<ChatMessage> buildTermMessages(
  List<TermCandidate> batch, {
  String sourceLanguage = 'japonais',
  String targetLanguage = 'français',
  String gameContext =
      'Monster Hunter Portable 3rd (jeu vidéo PSP de chasse aux monstres)',
}) =>
    [
      ChatMessage.system(
        [
          'Tu constitues le glossaire de traduction du jeu $gameContext, '
              'du $sourceLanguage vers le $targetLanguage.',
          'Tu reçois un objet JSON avec une liste "items" : chacun a un "id", '
              'un "term" (nom ou expression à traduire) et un "example" '
              '(phrase où il apparaît, pour le contexte).',
          'Donne pour chaque terme la traduction courte à utiliser partout : '
              'nom de monstre, d\'objet, de lieu ou d\'arme, ou mot courant du '
              'jeu. Si le terme est un nom propre sans équivalent, translittère-le.',
          'Réponds uniquement par {"items":[{"id":…,"translation":"…"}]} avec '
              'exactement un élément par item, sans commentaire.',
        ].join('\n'),
      ),
      ChatMessage.user(
        jsonEncode({
          'items': [
            for (var i = 0; i < batch.length; i++)
              {
                'id': i,
                'term': batch[i].term,
                'example': _clip(batch[i].example),
              },
          ],
        }),
      ),
    ];

/// Analyse la réponse : traduction proposée par terme (clé = position dans
/// [batchSize]). Éléments inconnus, vides ou en double ignorés. Lève
/// `TranslateError` (`invalidResponse`) sans JSON exploitable.
Map<int, String> parseTermTranslations(String content, int batchSize) {
  final json = extractJson(content);
  final items = switch (json) {
    final List<Object?> l => l,
    final Map<Object?, Object?> m when m['items'] is List =>
      m['items']! as List<Object?>,
    _ => null,
  };
  if (items == null) {
    throw const TranslateError(
      TranslateErrorKind.invalidResponse,
      'no glossary array found in the model output',
    );
  }
  final out = <int, String>{};
  for (final item in items) {
    if (item is! Map) continue;
    final id = item['id'] is int
        ? item['id']! as int
        : int.tryParse('${item['id']}'.trim());
    final tr = item['translation'];
    if (id == null ||
        id < 0 ||
        id >= batchSize ||
        tr is! String ||
        tr.trim().isEmpty ||
        tr.contains('\u0000') ||
        out.containsKey(id)) {
      continue;
    }
    out[id] = tr.trim();
  }
  return out;
}

/// Demande au modèle une traduction par candidat. Résultat : terme source →
/// traduction proposée (les termes sans réponse valide sont absents). Une
/// panne du fournisseur lève `TranslateError`.
Future<Map<String, String>> proposeTermTranslations({
  required ChatClient client,
  required String model,
  required List<TermCandidate> candidates,
  String targetLanguage = 'français',
  int batchSize = 25,
  CancelCheck? isCancelled,
}) async {
  final out = <String, String>{};
  for (var i = 0; i < candidates.length; i += batchSize) {
    if (isCancelled != null && isCancelled()) break;
    final batch = candidates.sublist(
      i,
      i + batchSize > candidates.length ? candidates.length : i + batchSize,
    );
    final r = await client.chat(
      model: model,
      messages: buildTermMessages(batch, targetLanguage: targetLanguage),
      temperature: 0.2,
      maxTokens: 2000,
      jsonSchema: termSchema(),
    );
    final parsed = parseTermTranslations(r.content, batch.length);
    for (final e in parsed.entries) {
      out[batch[e.key].term] = e.value;
    }
  }
  return out;
}

/// Prédicat d'annulation (vrai = arrêter avant le prochain lot).
typedef CancelCheck = bool Function();
