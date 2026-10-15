import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

// Table 0 : 3 slots dont l'index 2 est un alias de 0 ; table 1 nulle.
StringTableFile sample({String first = 'un\ndeux'}) => StringTableFile(
      unknownHeader: 0,
      tables: [
        StringTable(
          originalOffsets: const [12, 16, 12],
          slots: [
            StringSlot(index: 0, raw: b(first)),
            StringSlot(index: 1, raw: b('trois')),
            StringSlot(index: 2, raw: b(first), aliasOf: 0),
          ],
        ),
        null,
      ],
      endData: Uint8List(0),
    );

MhtoolsDump dumpWith(List<String> lines) => MhtoolsDump(
      fileListText: 'x.bin 0\nstring_table_0.txt\nstring_table_1.txt\n',
      tableTexts: ['${lines.join('\n')}\n', null],
      endData: Uint8List(0),
    );

void main() {
  late TdbDatabase db;
  setUp(() => db = TdbDatabase.openInMemory());
  tearDown(() => db.close());

  Future<void> importSource() => importSourceFile(
        db,
        fileId: 17,
        versionId: 'TEST',
        lba: 10,
        slotBytes: 4096,
        origBytes: 3000,
        file: sample(),
      );

  test('importSourceFile stores rows, hashes and aliases', () async {
    await importSource();
    final file = await db.select(db.gameFiles).getSingle();
    expect(file.id, 17);
    expect(file.codec, 'string_table_a');
    final rows = await (db.select(db.sourceStrings)
          ..orderBy([(t) => OrderingTerm.asc(t.slotIdx)]))
        .get();
    expect(rows.map((r) => (r.tableIdx, r.slotIdx)), [(0, 0), (0, 1), (0, 2)]);
    expect(rows[0].sourceText, 'un\ndeux');
    expect(rows[0].sourceHash.length, 40);
    expect(rows[0].sourceHash, rows[2].sourceHash);
    expect(rows[2].aliasOf, rows[0].id);
    expect(rows[0].aliasOf, isNull);
  });

  test('importSourceFile refuses a second import and keeps one set', () async {
    await importSource();
    await expectLater(importSource(), throwsA(isA<TdbError>()));
    expect((await db.select(db.sourceStrings).get()).length, 3);
  });

  test('importMhtoolsTranslations writes only changed non-alias slots',
      () async {
    await importSource();
    final dump = dumpWith(['UN<NEWLINE>DEUX', 'trois', 'UN<NEWLINE>DEUX']);
    final n = await importMhtoolsTranslations(
      db,
      fileId: 17,
      original: sample(),
      dump: dump,
      locale: 'fr',
    );
    expect(n, 1);
    final tr = await db.select(db.translations).getSingle();
    expect(tr.text_, 'UN\nDEUX');
    expect(tr.status, 'draft');
    expect(tr.revision, 1);
  });

  test('reimport updates only on change and bumps revision', () async {
    await importSource();
    Future<int> run(String l, {String status = 'draft'}) =>
        importMhtoolsTranslations(
          db,
          fileId: 17,
          original: sample(),
          dump: dumpWith([l, 'trois', l]),
          locale: 'fr',
          status: status,
        );
    expect(await run('A'), 1);
    expect(await run('A'), 0);
    expect(await run('B'), 1);
    expect(await run('B', status: 'translated'), 1);
    final tr = await db.select(db.translations).getSingle();
    expect((tr.text_, tr.status, tr.revision), ('B', 'translated', 3));
  });

  test('rejects unknown status, non-imported file, mismatching original',
      () async {
    Future<int> run({
      String status = 'draft',
      StringTableFile? original,
    }) =>
        importMhtoolsTranslations(
          db,
          fileId: 17,
          original: original ?? sample(),
          dump: dumpWith(['a', 'b', 'a']),
          locale: 'fr',
          status: status,
        );
    await expectLater(run(status: 'bogus'), throwsA(isA<TdbError>()));
    await expectLater(run(), throwsA(isA<TdbError>()));
    await importSource();
    await expectLater(
      run(original: sample(first: 'autre')),
      throwsA(isA<TdbError>()),
    );
    expect(await db.select(db.translations).get(), isEmpty);
  });

  test('incompatible dump leaves no partial import', () async {
    await importSource();
    await expectLater(
      importMhtoolsTranslations(
        db,
        fileId: 17,
        original: sample(),
        dump: dumpWith(['seulement une ligne']),
        locale: 'fr',
      ),
      throwsA(isA<FormatError>()),
    );
    expect(await db.select(db.translations).get(), isEmpty);
  });
}
