// Linter de traduction (docs/ARCHITECTURE.md §10.1 : tokens identiques,
// glossaire, espaces, ponctuation française).
//
// Les jetons du texte réel sont le texte, le saut de ligne (T15) et les codes
// `~Xnn` (1 197 chaînes sur 15 051 : couleurs `~C..`, boutons `~B..`, constat
// du 2026-10-15 ; T15 ne cherchait que des octets de contrôle) :
// « même multiensemble de jetons » = même nombre de sauts de
// ligne et mêmes codes. Aucune règle ne modifie le texte ; ce sont des avertissements.

/// Gravité d'un [LintIssue].
enum LintSeverity {
  /// À corriger : le jeu affichera autre chose que prévu.
  error,

  /// Probable oubli.
  warning,

  /// Suggestion.
  info,
}

/// Nature d'un [LintIssue].
enum LintKind {
  /// Traduction vide pour une source non vide.
  emptyTranslation,

  /// Nombre de sauts de ligne différent de la source.
  newlineCount,

  /// Codes `~Xnn` (couleurs, boutons…) différents de la source.
  controlCodes,

  /// Octet NUL (terminerait la chaîne dans le jeu).
  nulChar,

  /// Espace en début ou fin présent d'un seul côté.
  edgeWhitespace,

  /// Terme de glossaire obligatoire absent de la traduction.
  mandatoryTerm,

  /// Terme de glossaire (non obligatoire) absent de la traduction.
  suggestedTerm,

  /// Espace insécable manquante avant `: ; ! ?` (option).
  frenchSpacing,

  /// Caractère invisible ou de contrôle (U+200B/200C/200D/FEFF, tabulation,
  /// autres C0/C1 hors `\n`) plus fréquent que dans la source.
  /// [LintIssue.detail] : points de code `U+XXXX` distincts.
  invisibleChar,

  /// Kana ou kanji laissés dans la traduction. [LintIssue.detail] : nombre.
  residualJapanese,

  /// Caractère dont l'affichage en jeu n'a pas été mesuré (hors
  /// [LintOptions.displayableChars]). [LintIssue.detail] : points de code.
  unmeasuredChar,
}

/// Un constat du linter. [detail] est court et sans texte du jeu, sauf le
/// terme de glossaire concerné.
final class LintIssue {
  /// Voir les champs.
  const LintIssue(this.kind, this.severity, [this.detail = '']);

  final LintKind kind;
  final LintSeverity severity;
  final String detail;

  @override
  bool operator ==(Object other) =>
      other is LintIssue &&
      other.kind == kind &&
      other.severity == severity &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, severity, detail);

  @override
  String toString() => 'LintIssue(${kind.name}, ${severity.name}, $detail)';
}

/// Terme de glossaire vu par le linter.
final class GlossaryEntry {
  /// Voir les champs.
  const GlossaryEntry({
    required this.sourceTerm,
    required this.targetTerm,
    this.mandatory = false,
  });

  final String sourceTerm;
  final String targetTerm;
  final bool mandatory;
}

/// Options du linter.
final class LintOptions {
  /// Voir les champs.
  const LintOptions({this.frenchSpacing = false, this.displayableChars});

  /// Exige une espace insécable (U+00A0 ou U+202F) avant `: ; ! ?`. Désactivé
  /// par défaut : dépend de la police du jeu (phase 4).
  final bool frenchSpacing;

  /// Points de code dont l'affichage a été observé en jeu (p. ex.
  /// `measuredLatinChars()` de `mh_budget`, qui dépend de ce paquet). Null :
  /// pas de contrôle [LintKind.unmeasuredChar]. Le linter ne déclare lui-même
  /// aucun caractère « connu ».
  final Set<int>? displayableChars;
}

/// Termes de [glossary] dont le terme source figure dans [source].
List<GlossaryEntry> matchGlossary(
  String source,
  List<GlossaryEntry> glossary,
) =>
    [
      for (final g in glossary)
        if (g.sourceTerm.isNotEmpty && source.contains(g.sourceTerm)) g,
    ];

int _count(String s, String ch) {
  var n = 0;
  for (final u in s.codeUnits) {
    if (u == ch.codeUnitAt(0)) n++;
  }
  return n;
}

/// Contrôle [target] par rapport à [source]. Une traduction vide ne produit
/// que [LintKind.emptyTranslation] (et seulement si la source n'est pas vide).
List<LintIssue> lintTranslation({
  required String source,
  required String target,
  List<GlossaryEntry> glossary = const [],
  LintOptions options = const LintOptions(),
}) {
  if (target.isEmpty) {
    return source.trim().isEmpty
        ? const []
        : const [LintIssue(LintKind.emptyTranslation, LintSeverity.warning)];
  }
  final issues = <LintIssue>[];

  if (target.contains('\u0000')) {
    issues.add(const LintIssue(LintKind.nulChar, LintSeverity.error));
  }

  final sc = controlCodesOf(source);
  final tc = controlCodesOf(target);
  if (sc.join() != tc.join()) {
    final missing = [...sc];
    for (final c in tc) {
      missing.remove(c);
    }
    final extra = [...tc];
    for (final c in sc) {
      extra.remove(c);
    }
    issues.add(
      LintIssue(
        LintKind.controlCodes,
        LintSeverity.error,
        [
          if (missing.isNotEmpty) 'missing ${missing.join(' ')}',
          if (extra.isNotEmpty) 'extra ${extra.join(' ')}',
        ].join('; '),
      ),
    );
  }

  final sn = _count(source, '\n');
  final tn = _count(target, '\n');
  if (sn != tn) {
    issues.add(
      LintIssue(
        LintKind.newlineCount,
        LintSeverity.error,
        'source=$sn target=$tn',
      ),
    );
  }

  if (source.startsWith(' ') != target.startsWith(' ')) {
    issues.add(
      const LintIssue(LintKind.edgeWhitespace, LintSeverity.warning, 'leading'),
    );
  }
  if (source.endsWith(' ') != target.endsWith(' ')) {
    issues.add(
      const LintIssue(
        LintKind.edgeWhitespace,
        LintSeverity.warning,
        'trailing',
      ),
    );
  }

  for (final g in matchGlossary(source, glossary)) {
    if (target.contains(g.targetTerm)) continue;
    issues.add(
      LintIssue(
        g.mandatory ? LintKind.mandatoryTerm : LintKind.suggestedTerm,
        g.mandatory ? LintSeverity.warning : LintSeverity.info,
        g.targetTerm,
      ),
    );
  }

  final invisible = _invisibleExtra(source, target);
  if (invisible.isNotEmpty) {
    issues.add(
      LintIssue(
        LintKind.invisibleChar,
        LintSeverity.error,
        invisible.map(codePointLabel).join(' '),
      ),
    );
  }

  final jp = target.runes.where(isJapaneseRune).length;
  if (jp > 0) {
    issues.add(
      LintIssue(LintKind.residualJapanese, LintSeverity.warning, '$jp'),
    );
  }

  final known = options.displayableChars;
  if (known != null) {
    final unknown = <int>{
      for (final r in target.runes)
        if (r != 0x0A &&
            !known.contains(r) &&
            !isInvisibleRune(r) &&
            !isJapaneseRune(r))
          r,
    }.toList()
      ..sort();
    if (unknown.isNotEmpty) {
      issues.add(
        LintIssue(
          LintKind.unmeasuredChar,
          LintSeverity.info,
          unknown.map(codePointLabel).join(' '),
        ),
      );
    }
  }

  if (options.frenchSpacing) {
    for (var i = 1; i < target.length; i++) {
      final c = target[i];
      if (c != ':' && c != ';' && c != '!' && c != '?') continue;
      final prev = target[i - 1];
      if (prev == ' ' || prev == ' ') continue;
      // Début de ligne ou ponctuation doublée (« ?! ») : pas d'espace requise.
      if (prev == '\n' || '!?:;'.contains(prev)) continue;
      issues.add(LintIssue(LintKind.frenchSpacing, LintSeverity.warning, c));
    }
  }
  return issues;
}

final RegExp _controlCode = RegExp('~[A-Za-z][0-9A-Za-z]{2}');

/// Codes `~Xnn` de [s], triés (multiensemble).
List<String> controlCodesOf(String s) => [
      for (final m in _controlCode.allMatches(s)) m.group(0)!,
    ]..sort();

/// Caractère invisible ou de contrôle : C0 hors `\n` (tabulation comprise),
/// DEL, C1, U+200B/200C/200D (largeur nulle) et U+FEFF (BOM). NUL est traité
/// à part ([LintKind.nulChar]).
bool isInvisibleRune(int r) =>
    (r > 0x00 && r < 0x20 && r != 0x0A) ||
    (r >= 0x7F && r <= 0x9F) ||
    r == 0x200B ||
    r == 0x200C ||
    r == 0x200D ||
    r == 0xFEFF;

/// Kana (U+3040–30FF, U+31F0–31FF, U+FF66–FF9F) ou kanji (U+3400–4DBF,
/// U+4E00–9FFF, U+F900–FAFF).
bool isJapaneseRune(int r) =>
    (r >= 0x3040 && r <= 0x30FF) ||
    (r >= 0x31F0 && r <= 0x31FF) ||
    (r >= 0xFF66 && r <= 0xFF9F) ||
    (r >= 0x3400 && r <= 0x4DBF) ||
    (r >= 0x4E00 && r <= 0x9FFF) ||
    (r >= 0xF900 && r <= 0xFAFF);

/// `U+XXXX` (au moins 4 chiffres hexadécimaux, majuscules).
String codePointLabel(int r) =>
    'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// Caractères invisibles plus nombreux dans [target] que dans [source], triés.
List<int> _invisibleExtra(String source, String target) {
  final counts = <int, int>{};
  for (final r in target.runes) {
    if (isInvisibleRune(r)) counts[r] = (counts[r] ?? 0) + 1;
  }
  for (final r in source.runes) {
    final n = counts[r];
    if (n != null) counts[r] = n - 1;
  }
  return [
    for (final e in counts.entries)
      if (e.value > 0) e.key,
  ]..sort();
}
