import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
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

  Future<void> translate(String line, {String status = 'draft'}) =>
      importMhtoolsTranslations(
        db,
        fileId: 1,
        original: original,
        dump: dump([line, 'trois', line]),
        locale: 'fr',
        status: status,
      );

  Future<Map<int, FileBudget>> budgets({String minStatus = 'draft'}) =>
      computeFileBudgets(
        db: db,
        index: DataBinIndex([entry()]),
        readPlain: (_) => plain,
        locale: 'fr',
        fileIds: [1],
        minStatus: minStatus,
      );

  test('untranslated file: rebuilt equals the original', () async {
    final b = (await budgets())[1]!;
    expect((b.origBytes, b.slotBytes, b.rebuiltBytes), (2048, 2048, 2048));
    expect(b.fitsStrict, isTrue);
    expect(b.fitsSlot, isTrue);
    expect(b.strictMarginBytes, 0);
  });

  test('shorter text frees bytes; the size matches buildPatch', () async {
    await translate('UN'); // 'un\ndeux' (7 octets) -> 'UN' (2) : -5
    final b = (await budgets())[1]!;
    expect(b.rebuiltBytes, 2048 - 5);
    expect(b.strictMarginBytes, 5);
    expect(b.fitsStrict, isTrue);
    final built = await buildPatch(
      db: db,
      index: DataBinIndex([entry()]),
      readPlain: (_) => plain,
      locale: 'fr',
      minStatus: 'draft',
    );
    expect(built.reports.single.rebuiltBytes, b.rebuiltBytes);
  });

  test('longer text breaks strict then the slot', () async {
    await translate('x' * 20); // +13 octets : > orig, aligné 4096 > slot
    final b = (await budgets())[1]!;
    expect(b.rebuiltBytes, 2048 + 13);
    expect(b.fitsStrict, isFalse);
    expect(b.fitsSlot, isFalse);
    expect(b.strictMarginBytes, -13);
  });

  test('minStatus filters work in progress', () async {
    await translate('UN');
    expect((await budgets(minStatus: 'translated'))[1]!.rebuiltBytes, 2048);
    expect((await budgets())[1]!.rebuiltBytes, 2048 - 5);
  });

  test('unknown files and stale positions are rejected', () async {
    await translate('UN');
    await expectLater(
      computeFileBudgets(
        db: db,
        index: DataBinIndex(const []),
        readPlain: (_) => plain,
        locale: 'fr',
        fileIds: [1],
      ),
      throwsA(isA<FormatError>()),
    );
    // Original sans table 0 : la traduction n'a plus de position.
    final emptyFile = StringTableFile(
      unknownHeader: 8,
      tables: const [],
      endData: Uint8List(0),
    );
    final empty = slotBytesOf(emptyFile);
    await expectLater(
      computeFileBudgets(
        db: db,
        index: DataBinIndex([entry()]),
        readPlain: (_) => empty,
        locale: 'fr',
        fileIds: [1],
      ),
      throwsA(isA<TdbError>()),
    );
  });
}
