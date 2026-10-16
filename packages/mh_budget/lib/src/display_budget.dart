// Budget d'affichage, niveaux 3 (pixels) et 4 (lignes)
// (docs/ARCHITECTURE.md §8.4 et §8.6).
//
// Ces contrôles sont des **avertissements** : ils n'arrêtent jamais un build.
// Ils ne s'appliquent que si le profil contient une limite **mesurée**
// (`LengthProfile`) : sans limite, aucun avertissement n'est produit.
//
// Ce qui est observé en jeu (docs/CALIBRATION.md §5) : pas de retour à la
// ligne automatique, le texte déborde ; le nombre de lignes est donc celui des
// sauts de ligne + 1. La façon dont un dialogue est découpé en pages n'est
// pas connue : pour un profil `paginated`, la limite de lignes n'est pas
// contrôlée.

import 'glyph_metrics.dart';
import 'length_profile.dart';

/// Nature d'un avertissement d'affichage (valeurs du rapport JSON §8.6).
enum DisplayWarningKind {
  /// Une ligne dépasse la largeur maximale du profil (`px_overflow`).
  pxOverflow('px_overflow'),

  /// Le texte a plus de lignes que le profil (`lines_overflow`).
  linesOverflow('lines_overflow'),

  /// Un caractère dont la largeur n'a pas été mesurée en jeu
  /// (`unknown_glyph`) : `value` = point de code.
  unknownGlyph('unknown_glyph');

  const DisplayWarningKind(this.jsonName);

  /// Nom dans le rapport JSON.
  final String jsonName;
}

/// Un constat d'affichage sur une chaîne.
final class DisplayIssue {
  /// Voir les champs.
  const DisplayIssue(this.kind, this.value, {this.max, this.line});

  final DisplayWarningKind kind;

  /// Largeur (px), nombre de lignes, ou point de code selon [kind].
  final int value;

  /// Limite dépassée (`null` pour `unknown_glyph`).
  final int? max;

  /// Ligne concernée (0 = première), `null` si le constat porte sur le texte.
  final int? line;

  @override
  bool operator ==(Object other) =>
      other is DisplayIssue &&
      other.kind == kind &&
      other.value == value &&
      other.max == max &&
      other.line == line;

  @override
  int get hashCode => Object.hash(kind, value, max, line);

  @override
  String toString() => 'DisplayIssue(${kind.jsonName}, $value, max: $max, '
      'line: $line)';
}

/// Résultat de [evaluateDisplay].
final class DisplayEvaluation {
  /// Voir les champs.
  DisplayEvaluation({
    required List<DisplayIssue> issues,
    required this.lineCount,
    required this.maxPx,
    required this.exact,
  }) : issues = List.unmodifiable(issues);

  final List<DisplayIssue> issues;

  /// Nombre de lignes du texte.
  final int lineCount;

  /// Largeur de la plus large ligne (parties de largeur connue).
  final int maxPx;

  /// Toutes les largeurs sont complètes (aucun code, marqueur ni caractère
  /// inconnu) : sinon [maxPx] est un minimum.
  final bool exact;

  /// Aucun constat.
  bool get ok => issues.isEmpty;
}

/// Constat localisé dans un fichier (une entrée de `warnings`, §8.6).
final class DisplayWarning {
  /// Voir les champs.
  const DisplayWarning({
    required this.tableIdx,
    required this.slotIdx,
    required this.issue,
  });

  final int tableIdx;
  final int slotIdx;
  final DisplayIssue issue;

  /// `{"table", "slot", "kind", "value", "max"}` (+ `line` si connu).
  Map<String, Object> toJson() => {
        'table': tableIdx,
        'slot': slotIdx,
        'kind': issue.kind.jsonName,
        'value': issue.value,
        if (issue.max != null) 'max': issue.max!,
        if (issue.line != null) 'line': issue.line!,
      };
}

/// Contrôle l'affichage de [text] pour le profil [profile], avec les
/// métriques [metrics].
///
/// - largeur : une ligne dont la largeur **connue** dépasse `maxPx` donne un
///   `px_overflow` (la largeur réelle peut être plus grande si la ligne
///   contient des codes ou des caractères inconnus) ; exige `maxPx > 0` et un
///   contexte de police connu de [metrics] ;
/// - lignes : plus de `maxLines` lignes donne un `lines_overflow` (profil non
///   paginé) ;
/// - caractères inconnus : un `unknown_glyph` par point de code distinct, quand
///   la largeur est contrôlée.
///
/// Un profil sans limite mesurée, ou dont le contexte de police est inconnu de
/// [metrics], ne produit aucun constat de largeur.
DisplayEvaluation evaluateDisplay(
  String text,
  LengthProfile profile,
  GlyphMetrics metrics,
) {
  final lines = text.split('\n');
  final issues = <DisplayIssue>[];
  var maxPx = 0;
  var exact = true;

  final font = profile.fontContext;
  final measure = font != null && metrics.context(font) != null;
  if (measure) {
    final seen = <int>{};
    for (var i = 0; i < lines.length; i++) {
      final m = metrics.measureLine(lines[i], font);
      if (m.px > maxPx) maxPx = m.px;
      if (!m.exact) exact = false;
      if (profile.checksWidth && m.px > profile.maxPx) {
        issues.add(
          DisplayIssue(
            DisplayWarningKind.pxOverflow,
            m.px,
            max: profile.maxPx,
            line: i,
          ),
        );
      }
      if (profile.checksWidth) {
        for (final c in m.unknownGlyphs) {
          if (seen.add(c)) {
            issues
                .add(DisplayIssue(DisplayWarningKind.unknownGlyph, c, line: i));
          }
        }
      }
    }
  }
  if (profile.checksLines &&
      !profile.paginated &&
      lines.length > profile.maxLines) {
    issues.add(
      DisplayIssue(
        DisplayWarningKind.linesOverflow,
        lines.length,
        max: profile.maxLines,
      ),
    );
  }
  return DisplayEvaluation(
    issues: issues,
    lineCount: lines.length,
    maxPx: maxPx,
    exact: exact,
  );
}

/// Nombre d'avertissements par nature (clés = `DisplayWarningKind.jsonName`),
/// pour les résumés ; vide s'il n'y en a pas.
Map<String, int> summarizeDisplayWarnings(Iterable<DisplayWarning> warnings) {
  final out = <String, int>{};
  for (final w in warnings) {
    final k = w.issue.kind.jsonName;
    out[k] = (out[k] ?? 0) + 1;
  }
  return out;
}
