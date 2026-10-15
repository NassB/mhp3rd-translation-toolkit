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
  const LintOptions({this.frenchSpacing = false});

  /// Exige une espace insécable (U+00A0 ou U+202F) avant `: ; ! ?`. Désactivé
  /// par défaut : dépend de la police du jeu (phase 4).
  final bool frenchSpacing;
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
