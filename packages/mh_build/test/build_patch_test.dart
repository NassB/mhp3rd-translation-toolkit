import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
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

  setUp(() async {
    db = TdbDatabase.openInMemory();
    original = model();
    plain = slotBytesOf(original);
    expect(plain.length, 2048);
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

  Future<void> translate(String line, {String status = 'translated'}) =>
      importMhtoolsTranslations(
        db,
        fileId: 1,
        original: original,
        dump: dump([line, 'trois', line]),
        locale: 'fr',
        status: status,
      );

  Future<BuildResult> run({
    DataBinEntry? e,
    Uint8List? plainOverride,
    String minStatus = 'translated',
  }) =>
      buildPatch(
        db: db,
        index: DataBinIndex([e ?? entry()]),
        readPlain: (_) => plainOverride ?? plain,
        locale: 'fr',
        minStatus: minStatus,
      );

  test('nothing to translate: no patch', () async {
    final r = await run();
    expect(r.patch, isNull);
    expect(r.reports, isEmpty);
  });

  test('shorter text keeps endData at its original position', () async {
    await translate('UN');
    final r = await run();
    expect(r.ok, isTrue);
    final block = r.patch!.blocks.single;
    expect(block.offset, 5 * sectorSize);
    expect(block.data.length, 2048);
    final out = const DataCipher().decrypt(block.data, 5);
    expect(out.sublist(2048 - 100), List.filled(100, 0x5A));
    final back = decodeStringTableA(out);
    final slots = back.tables[0]!.slots;
    expect(slots[0].raw, b('UN'));
    expect(slots[1].raw, b('trois'));
    expect(slots[2].aliasOf, 0);
    expect(back.tables[1], isNull);
    expect(back.unknownHeader, original.unknownHeader);
    expect(r.reports.single.status, BudgetStatus.ok);
  });

  test('unencrypted entries are written as plain bytes', () async {
    await translate('UN');
    final r = await run(e: entry(encrypted: false));
    final block = r.patch!.blocks.single;
    expect(block.data.sublist(2048 - 100), List.filled(100, 0x5A));
    expect(decodeStringTableA(block.data).tables[0]!.slots[0].raw, b('UN'));
  });

  test('text that does not fit blocks the whole build', () async {
    await translate('x' * 2000);
    final r = await run();
    expect(r.ok, isFalse);
    expect(r.patch, isNull);
    expect(r.reports.single.status, BudgetStatus.slotOverflow);
  });

  test('draft is excluded unless minStatus allows it', () async {
    await translate('UN', status: 'draft');
    expect((await run()).reports, isEmpty);
    final r = await run(minStatus: 'draft');
    expect(r.ok, isTrue);
    expect(r.patch!.blocks, hasLength(1));
  });

  test('a stale database is rejected', () async {
    await translate('UN');
    final other = slotBytesOf(model(first: 'autre'));
    await expectLater(
      run(plainOverride: other),
      throwsA(isA<TdbError>()),
    );
  });

  test('unknown file id is rejected', () async {
    await translate('UN');
    await expectLater(
      buildPatch(
        db: db,
        index: DataBinIndex(const []),
        readPlain: (_) => plain,
        locale: 'fr',
      ),
      throwsA(isA<FormatError>()),
    );
  });
}
