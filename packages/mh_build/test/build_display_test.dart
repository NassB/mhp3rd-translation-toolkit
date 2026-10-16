import 'dart:typed_data';

import 'package:mh_budget/mh_budget.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

import 'support/build_fixtures.dart';

void main() {
  late TdbDatabase db;
  late StringTableFile original;
  late Uint8List plain;

  final metrics = GlyphMetrics(
    contexts: const [FontContext(id: 'px7', advancePx: 7)],
  );
  final profiles = LengthProfiles(const [
    LengthProfile(id: 'tight', fontContext: 'px7', maxPx: 20, maxLines: 1),
    LengthProfile(id: 'lines', maxLines: 2),
    LengthProfile(id: 'none'),
  ]);
  final display = DisplayCheck(profiles: profiles, metrics: metrics);

  setUp(() async {
    db = TdbDatabase.openInMemory();
    original = model();
    plain = slotBytesOf(original);
    await importSourceFile(
      db,
      fileId: 1,
      versionId: 'TEST',
      lba: 5,
      slotBytes: 2048,
      origBytes: 2048,
      file: original,
    );
  });
  tearDown(() => db.close());

  Future<void> translate(List<String> lines) => importMhtoolsTranslations(
        db,
        fileId: 1,
        original: original,
        dump: dump([for (final l in lines) l.replaceAll('\n', '<NEWLINE>')]),
        locale: 'fr',
        status: 'translated',
      );

  Future<BuildResult> run({DisplayCheck? check}) => buildPatch(
        db: db,
        index: DataBinIndex([entry()]),
        readPlain: (_) => plain,
        locale: 'fr',
        display: check,
      );

  Future<void> assign(String? id) =>
      ProfileRepository(db).setTableProfile(1, 0, id);

  test('without a display check there are no warnings', () async {
    await translate(['UN', 'quatre', 'UN']);
    await assign('tight');
    final r = await run();
    expect(r.reports.single.warnings, isEmpty);
    expect(r.reports.single.toJson()['warnings'], isEmpty);
  });

  test('px, lines and unknown glyph warnings, never blocking the build',
      () async {
    await translate(['a\nb\nc', 'quatre', 'a\nb\nc']);
    await assign('tight');
    final r = await run(check: display);
    expect(r.ok, isTrue);
    expect(r.patch, isNotNull);
    final w = r.reports.single.warnings.map((x) => x.toJson()).toList();
    expect(w, [
      // table 0, slot 0 : 3 lignes > 1 ; 1 caractère = 7 px, dans la limite
      {'table': 0, 'slot': 0, 'kind': 'lines_overflow', 'value': 3, 'max': 1},
      // table 0, slot 1 : « quatre » = 42 px > 20
      {
        'table': 0,
        'slot': 1,
        'kind': 'px_overflow',
        'value': 42,
        'max': 20,
        'line': 0,
      },
    ]);
  });

  test('a glyph not measured in game is reported when width is checked',
      () async {
    await translate(['a…', 'ok', 'a…']);
    await assign('tight');
    final r = await run(check: display);
    final kinds = [
      for (final x in r.reports.single.warnings)
        '${x.slotIdx}:${x.issue.kind.jsonName}',
    ];
    expect(kinds, ['0:unknown_glyph']);
    expect(r.reports.single.warnings.single.issue.value, 0x2026);
  });

  test('a profile without limit, or no profile, gives no warning', () async {
    await translate(['a\nb\nc', 'trois trois trois', 'a\nb\nc']);
    await assign('none');
    expect((await run(check: display)).reports.single.warnings, isEmpty);
    await assign(null);
    expect((await run(check: display)).reports.single.warnings, isEmpty);
  });

  test('lines only: a profile without font checks the line count', () async {
    await translate(['a\nb\nc', 'quatre', 'a\nb\nc']);
    await assign('lines');
    final w = (await run(check: display)).reports.single.warnings;
    expect(w.map((x) => x.issue.kind), [DisplayWarningKind.linesOverflow]);
    expect(w.single.slotIdx, 0);
  });

  test('a string override beats the table assignment', () async {
    await translate(['UN', 'quatre', 'UN']);
    await assign('none');
    final slots = await TranslationRepository(db, locale: 'fr').slots(1);
    final id = slots.firstWhere((s) => s.slotIdx == 1).sourceId;
    await ProfileRepository(db).setStringProfile(id, 'tight');
    final w = (await run(check: display)).reports.single.warnings;
    expect([for (final x in w) x.slotIdx], [1]);
  });

  test('the JSON report carries the warnings (ARCHITECTURE 8.6)', () async {
    await translate(['UN', 'quatre', 'UN']);
    await assign('tight');
    final json = (await run(check: display)).reports.single.toJson();
    expect(json['warnings'], [
      {
        'table': 0,
        'slot': 1,
        'kind': 'px_overflow',
        'value': 42,
        'max': 20,
        'line': 0,
      },
    ]);
    expect(json['status'], 'ok');
  });

  test('DisplayCheck.tryLoad: absent files mean no check', () {
    expect(
      DisplayCheck.tryLoad(
        profilesPath: 'nope/profiles.yaml',
        metricsPath: 'nope/metrics.yaml',
      ),
      isNull,
    );
    final real = DisplayCheck.tryLoad(
      profilesPath: '../../$defaultProfiles',
      metricsPath: '../../$defaultFontMetrics',
    );
    expect(real, isNotNull);
    expect(real!.profiles.ids, contains('dialogue'));
  });
}
