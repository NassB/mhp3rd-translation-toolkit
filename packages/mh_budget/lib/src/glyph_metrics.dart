// Métriques de glyphes pour le budget en pixels (docs/ARCHITECTURE.md §8.4,
// docs/CALIBRATION.md §5).
//
// Ce qui est mesuré (captures de l'ISO de calibrage, PPSSPP) : la police
// latine du jeu est **à chasse fixe** dans chaque élément d'interface ; le
// pas dépend de l'élément (6, 7 ou 9 px de la PSP), pas du caractère. La
// largeur d'une ligne latine est donc « nombre de caractères × pas du
// contexte ».
//
// Ce qui n'est PAS mesuré, et reste inconnu plutôt qu'inventé :
// - la largeur des caractères japonais (`wideAdvancePx`, `null` par défaut) ;
// - la largeur des codes `~Xnn` (couleur, bouton…) : listés, jamais comptés ;
// - la largeur des marqueurs de format `%d`/`%s` (variable) : listés ;
// - les caractères latins hors de l'ensemble mesuré (`knownChars`).
// Une ligne qui en contient n'est pas « exacte » (`LineMeasure.exact`).

/// Un contexte d'affichage : un élément d'interface avec sa police.
final class FontContext {
  /// Voir les champs.
  const FontContext({
    required this.id,
    required this.advancePx,
    this.description = '',
  });

  /// Identifiant stable (ex. `px7`).
  final String id;

  /// Pas d'un caractère latin, en pixels de la PSP.
  final int advancePx;

  /// Où il a été observé (information, non utilisée par le calcul).
  final String description;
}

/// Résultat de la mesure d'une ligne.
final class LineMeasure {
  /// Voir les champs.
  const LineMeasure({
    required this.px,
    required this.glyphs,
    required this.codes,
    required this.placeholders,
    required this.unknownGlyphs,
  });

  /// Largeur des seuls caractères de largeur connue, en pixels.
  final int px;

  /// Nombre de caractères comptés dans [px].
  final int glyphs;

  /// Codes `~Xnn` rencontrés (largeur non comptée).
  final List<String> codes;

  /// Nombre de marqueurs `%d`/`%s`… rencontrés (largeur non comptée).
  final int placeholders;

  /// Points de code de largeur inconnue (non comptés).
  final List<int> unknownGlyphs;

  /// Vrai si la largeur est complète : aucun code, marqueur ni caractère
  /// inconnu.
  bool get exact => codes.isEmpty && placeholders == 0 && unknownGlyphs.isEmpty;
}

/// Résultat de la mesure d'un texte (une entrée par ligne).
final class TextMeasure {
  /// Voir les champs.
  TextMeasure(List<LineMeasure> lines) : lines = List.unmodifiable(lines);

  final List<LineMeasure> lines;

  /// Largeur de la plus large ligne (parties connues).
  int get maxPx => lines.fold(0, (m, l) => l.px > m ? l.px : m);

  /// Toutes les lignes sont exactes.
  bool get exact => lines.every((l) => l.exact);
}

/// Caractères latins dont l'affichage a été **observé** : ASCII imprimable,
/// lettres accentuées `éèêëàâùûôîïçÉÈÀÇ` et guillemets `«»`.
Set<int> measuredLatinChars() => {
      for (var c = 0x20; c <= 0x7E; c++) c,
      ...'éèêëàâùûôîïçÉÈÀÇ«»'.runes,
    };

final RegExp _token = RegExp(
  r'~[A-Za-z][0-9A-Za-z]{2}|%[-+ 0#]*[0-9]*(?:\.[0-9]+)?[sdixXcfu]',
);

bool _isWide(int c) =>
    (c >= 0x3000 && c <= 0x30FF) ||
    (c >= 0x3400 && c <= 0x9FFF) ||
    (c >= 0xFF00 && c <= 0xFFEF);

/// Métriques d'un ensemble de contextes.
final class GlyphMetrics {
  /// Voir les champs. [knownChars] : points de code latins de largeur connue
  /// (défaut : [measuredLatinChars]) ; [wideAdvancePx] : pas d'un caractère
  /// japonais, `null` tant qu'il n'est pas mesuré.
  GlyphMetrics({
    required Iterable<FontContext> contexts,
    Set<int>? knownChars,
    this.wideAdvancePx,
  })  : contexts = {for (final c in contexts) c.id: c},
        knownChars = knownChars ?? measuredLatinChars();

  final Map<String, FontContext> contexts;
  final Set<int> knownChars;
  final int? wideAdvancePx;

  /// Contexte [id], ou `null`.
  FontContext? context(String id) => contexts[id];

  /// Nombre maximal de caractères latins d'une ligne de [maxPx] pixels.
  int maxChars(int maxPx, String contextId) =>
      maxPx ~/ _context(contextId).advancePx;

  /// Mesure une ligne (sans saut de ligne) dans le contexte [contextId].
  /// Lève [ArgumentError] si le contexte est inconnu.
  LineMeasure measureLine(String line, String contextId) {
    final advance = _context(contextId).advancePx;
    var px = 0;
    var glyphs = 0;
    final codes = <String>[];
    var placeholders = 0;
    final unknown = <int>[];

    void run(String text) {
      for (final c in text.runes) {
        if (_isWide(c)) {
          if (wideAdvancePx == null) {
            unknown.add(c);
          } else {
            px += wideAdvancePx!;
            glyphs++;
          }
        } else if (knownChars.contains(c)) {
          px += advance;
          glyphs++;
        } else {
          unknown.add(c);
        }
      }
    }

    var last = 0;
    for (final m in _token.allMatches(line)) {
      run(line.substring(last, m.start));
      final t = m.group(0)!;
      if (t.startsWith('~')) {
        codes.add(t);
      } else {
        placeholders++;
      }
      last = m.end;
    }
    run(line.substring(last));
    return LineMeasure(
      px: px,
      glyphs: glyphs,
      codes: codes,
      placeholders: placeholders,
      unknownGlyphs: unknown,
    );
  }

  /// Mesure un texte : une mesure par ligne (séparées par `\n`).
  TextMeasure measure(String text, String contextId) => TextMeasure([
        for (final line in text.split('\n')) measureLine(line, contextId),
      ]);

  FontContext _context(String id) {
    final c = contexts[id];
    if (c == null) throw ArgumentError.value(id, 'contextId', 'unknown');
    return c;
  }
}
