import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mh_font_metrics'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String yaml) {
    final p = '${tmp.path}/font_metrics.yaml';
    File(p).writeAsStringSync(yaml);
    return p;
  }

  test('the repository config loads and holds the measured contexts', () {
    final m = loadFontMetrics('../../$defaultFontMetrics');
    expect(
      {for (final c in m.contexts.values) c.id: c.advancePx},
      {'px7': 7, 'px6': 6, 'px9': 9},
    );
    expect(m.wideAdvancePx, isNull); // japonais : non mesuré
    expect(m.measureLine('Bonjour', 'px6').px, 42);
    expect(m.measureLine('éèêëàâùûôîïçÉÈÀÇ«»', 'px7').exact, isTrue);
  });

  test('a custom file: contexts, wide advance and extra characters', () {
    final m = loadFontMetrics(
      write(
        'wide_advance_px: 14\n'
        'extra_known_chars: "…"\n'
        'contexts:\n'
        '  - {id: a, advance_px: 5, observed: "x"}\n'
        '  - {id: b, advance_px: 8}\n',
      ),
    );
    expect(m.wideAdvancePx, 14);
    expect(m.measureLine('a…', 'a').px, 10);
    expect(m.context('a')!.description, 'x');
    expect(m.context('b')!.description, '');
  });

  test('invalid files are rejected with a FormatError', () {
    final bad = <String>[
      '- 1\n',
      'contexts: []\n',
      'contexts:\n  - {id: a, advance_px: 0}\n',
      'contexts:\n  - {id: a, advance_px: 7}\n  - {id: a, advance_px: 6}\n',
      'contexts:\n  - {id: "", advance_px: 7}\n',
      'wide_advance_px: -3\ncontexts:\n  - {id: a, advance_px: 7}\n',
      'extra_known_chars: 5\ncontexts:\n  - {id: a, advance_px: 7}\n',
      'contexts:\n  - 3\n',
      'a: [1\n',
    ];
    for (final y in bad) {
      expect(
        () => loadFontMetrics(write(y)),
        throwsA(isA<FormatError>()),
        reason: y,
      );
    }
    expect(
      () => loadFontMetrics('${tmp.path}/absent.yaml'),
      throwsA(isA<FormatError>()),
    );
  });
}
