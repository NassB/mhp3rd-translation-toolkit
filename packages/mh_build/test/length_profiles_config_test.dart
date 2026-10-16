import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mh_profiles'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String yaml) {
    final p = '${tmp.path}/profiles.yaml';
    File(p).writeAsStringSync(yaml);
    return p;
  }

  test('the repository config loads, is unmeasured and warns about nothing',
      () {
    final metrics = loadFontMetrics('../../$defaultFontMetrics');
    final ps = loadLengthProfiles('../../$defaultProfiles', metrics: metrics);
    expect(ps.ids, {
      'menu_label',
      'item_name',
      'item_description',
      'quest_title',
      'dialogue',
    });
    expect(ps['dialogue']!.paginated, isTrue);
    expect(ps['dialogue']!.maxLines, 3);
    for (final p in ps.all) {
      expect(p.maxPx, 0, reason: '${p.id}: max_px not measured');
      expect(p.fontContext, isNull, reason: '${p.id}: font not measured');
      expect(p.checksWidth, isFalse);
    }
  });

  test('a custom file with measured values', () {
    final ps = loadLengthProfiles(
      write(
        'profiles:\n'
        '  a: {max_px: 220, max_lines: 2, font_context: px7, description: "d"}\n'
        '  b: {}\n',
      ),
    );
    expect(ps['a']!.checksWidth, isTrue);
    expect(ps['a']!.description, 'd');
    expect(ps['b']!.hasLimits, isFalse);
  });

  test('font_context must exist in the metrics when they are given', () {
    final metrics = loadFontMetrics('../../$defaultFontMetrics');
    const y = 'profiles:\n  a: {font_context: px99}\n';
    expect(() => loadLengthProfiles(write(y)), returnsNormally);
    expect(
      () => loadLengthProfiles(write(y), metrics: metrics),
      throwsA(isA<FormatError>()),
    );
    expect(
      () => loadLengthProfiles(
        write('profiles:\n  a: {font_context: px7}\n'),
        metrics: metrics,
      ),
      returnsNormally,
    );
  });

  test('invalid files are rejected with a FormatError', () {
    final bad = <String>[
      '- 1\n',
      'profiles: [a]\n',
      'profiles:\n  a: 3\n',
      'profiles:\n  a: {max_px: -1}\n',
      'profiles:\n  a: {max_lines: "x"}\n',
      'profiles:\n  a: {font_context: 5}\n',
      'profiles:\n  a: {paginated: "yes"}\n',
      'profiles:\n  "": {}\n',
      'a: [1\n',
    ];
    for (final y in bad) {
      expect(
        () => loadLengthProfiles(write(y)),
        throwsA(isA<FormatError>()),
        reason: y,
      );
    }
    expect(
      () => loadLengthProfiles('${tmp.path}/absent.yaml'),
      throwsA(isA<FormatError>()),
    );
  });
}
