import 'package:mh_budget/mh_budget.dart';
import 'package:test/test.dart';

void main() {
  final metrics = GlyphMetrics(
    contexts: const [FontContext(id: 'px7', advancePx: 7)],
  );
  const wide = LengthProfile(
    id: 'p',
    fontContext: 'px7',
    maxPx: 70,
    maxLines: 2,
  );

  test('a text within every limit has no issue', () {
    final e = evaluateDisplay('0123456789\nabc', wide, metrics);
    expect(e.issues, isEmpty);
    expect((e.lineCount, e.maxPx, e.exact, e.ok), (2, 70, true, true));
  });

  test('px_overflow names the line, width and limit', () {
    final e = evaluateDisplay('short\n01234567890', wide, metrics);
    expect(e.issues, [
      const DisplayIssue(DisplayWarningKind.pxOverflow, 77, max: 70, line: 1),
    ]);
    expect(e.maxPx, 77);
  });

  test('exactly the limit is accepted', () {
    expect(evaluateDisplay('0123456789', wide, metrics).ok, isTrue);
  });

  test('lines_overflow counts newlines + 1 (no automatic wrapping)', () {
    final e = evaluateDisplay('a\nb\nc', wide, metrics);
    expect(e.issues, [
      const DisplayIssue(DisplayWarningKind.linesOverflow, 3, max: 2),
    ]);
    // Une très longue ligne ne crée pas de ligne supplémentaire.
    expect(
      evaluateDisplay('a' * 200, wide, metrics)
          .issues
          .where((i) => i.kind == DisplayWarningKind.linesOverflow),
      isEmpty,
    );
  });

  test('a paginated profile does not check the line count', () {
    const dialogue = LengthProfile(id: 'd', maxLines: 1, paginated: true);
    expect(evaluateDisplay('a\nb\nc\nd', dialogue, metrics).issues, isEmpty);
  });

  test('unknown glyphs are listed once each, only when width is checked', () {
    final e = evaluateDisplay('a…b…\ncœ', wide, metrics);
    expect(
      [
        for (final i in e.issues)
          if (i.kind == DisplayWarningKind.unknownGlyph) i.value,
      ],
      [0x2026, 0x153],
    );
    expect(e.exact, isFalse);
    const noWidth = LengthProfile(id: 'n', maxLines: 5);
    expect(evaluateDisplay('a…', noWidth, metrics).issues, isEmpty);
  });

  test('codes and placeholders make the width a lower bound', () {
    final e = evaluateDisplay('~C02abc %d~C00', wide, metrics);
    expect(e.exact, isFalse);
    expect(e.maxPx, 28); // « abc  »: 4 glyphs known? a b c + space
    expect(e.issues, isEmpty);
    // Le minimum connu dépasse déjà la limite : constat certain.
    final over = evaluateDisplay('~C02${'a' * 11} %d', wide, metrics);
    expect(over.issues.single.kind, DisplayWarningKind.pxOverflow);
  });

  test('a profile without measured limit gives nothing', () {
    const empty = LengthProfile(id: 'e');
    final e = evaluateDisplay('a' * 500 + '\n' * 20, empty, metrics);
    expect(e.issues, isEmpty);
    // Limite de largeur sans police : rien non plus.
    const noFont = LengthProfile(id: 'f', maxPx: 10);
    expect(evaluateDisplay('a' * 50, noFont, metrics).issues, isEmpty);
    // Police inconnue des métriques : rien.
    const badFont = LengthProfile(id: 'g', maxPx: 10, fontContext: 'px99');
    expect(evaluateDisplay('a' * 50, badFont, metrics).issues, isEmpty);
  });

  test('DisplayWarning serializes like the report format', () {
    const w = DisplayWarning(
      tableIdx: 3,
      slotIdx: 41,
      issue: DisplayIssue(DisplayWarningKind.pxOverflow, 212, max: 196),
    );
    expect(w.toJson(), {
      'table': 3,
      'slot': 41,
      'kind': 'px_overflow',
      'value': 212,
      'max': 196,
    });
    const g = DisplayWarning(
      tableIdx: 0,
      slotIdx: 0,
      issue: DisplayIssue(DisplayWarningKind.unknownGlyph, 0x2026, line: 2),
    );
    expect(g.toJson().containsKey('max'), isFalse);
    expect(g.toJson()['line'], 2);
  });

  test('BudgetReport keeps its status when warnings are attached', () {
    final r = evaluateFileBudget(
      fileId: 1,
      origBytes: 100,
      rebuiltBytes: 90,
      slotBytes: 2048,
    ).withWarnings(const [
      DisplayWarning(
        tableIdx: 0,
        slotIdx: 0,
        issue: DisplayIssue(DisplayWarningKind.linesOverflow, 3, max: 1),
      ),
    ]);
    expect(r.isOk, isTrue);
    expect(r.warnings, hasLength(1));
    expect((r.toJson()['warnings']! as List).single, {
      'table': 0,
      'slot': 0,
      'kind': 'lines_overflow',
      'value': 3,
      'max': 1,
    });
  });
}
