import 'package:mh_budget/mh_budget.dart';
import 'package:test/test.dart';

void main() {
  final metrics = GlyphMetrics(
    contexts: const [
      FontContext(id: 'px7', advancePx: 7, description: 'listes'),
      FontContext(id: 'px6', advancePx: 6),
    ],
  );

  test('a latin line is characters × the context advance', () {
    final m = metrics.measureLine('Bonjour', 'px7');
    expect((m.px, m.glyphs, m.exact), (49, 7, true));
    expect(metrics.measureLine('Bonjour', 'px6').px, 42);
    expect(metrics.measureLine('', 'px7').px, 0);
  });

  test('the advance does not depend on the character (monospace)', () {
    for (final s in ['iiiiiiiiii', 'WWWWWWWWWW', 'MMMMMMMMMM', '0123456789']) {
      expect(metrics.measureLine(s, 'px7').px, 70, reason: s);
    }
    expect(metrics.measureLine(' .,;:!?\'"«»()-/%', 'px7').px, 7 * 16);
  });

  test('accents measured in game are known', () {
    final m = metrics.measureLine('éèêëàâùûôîïçÉÈÀÇ', 'px7');
    expect((m.px, m.exact), (7 * 16, true));
  });

  test('codes and placeholders are listed, never counted', () {
    final m = metrics.measureLine('~C02Rang %d~C00 ok', 'px7');
    expect(m.codes, ['~C02', '~C00']);
    expect(m.placeholders, 1);
    expect(m.glyphs, 8); // « Rang  ok » : R a n g + espace + espace + o k
    expect(m.px, 56);
    expect(m.exact, isFalse);
  });

  test('unknown glyphs are reported, not guessed', () {
    final m = metrics.measureLine('a…b', 'px7');
    expect(m.unknownGlyphs, ['…'.runes.first]);
    expect(m.px, 14);
    expect(m.exact, isFalse);
  });

  test('japanese is unknown until its advance is measured', () {
    final unknown = metrics.measureLine('こんにちは', 'px7');
    expect((unknown.px, unknown.unknownGlyphs.length), (0, 5));
    final withWide = GlyphMetrics(
      contexts: const [FontContext(id: 'px7', advancePx: 7)],
      wideAdvancePx: 14,
    );
    final m = withWide.measureLine('こんにちは', 'px7');
    expect((m.px, m.glyphs, m.exact), (70, 5, true));
    // Mélange japonais et latin.
    expect(withWide.measureLine('Aあ', 'px7').px, 21);
  });

  test('extra known characters extend the measured set', () {
    final m = GlyphMetrics(
      contexts: const [FontContext(id: 'px7', advancePx: 7)],
      knownChars: {...measuredLatinChars(), '…'.runes.first},
    );
    expect(m.measureLine('a…b', 'px7').exact, isTrue);
  });

  test('a text is measured line by line', () {
    final t = metrics.measure('abc\nabcdef\n', 'px7');
    expect([for (final l in t.lines) l.px], [21, 42, 0]);
    expect(t.maxPx, 42);
    expect(t.exact, isTrue);
  });

  test('maxChars and unknown contexts', () {
    expect(metrics.maxChars(235, 'px6'), 39);
    expect(metrics.maxChars(235, 'px7'), 33);
    expect(() => metrics.measureLine('a', 'nope'), throwsArgumentError);
    expect(metrics.context('px7')!.description, 'listes');
    expect(metrics.context('nope'), isNull);
  });
}
