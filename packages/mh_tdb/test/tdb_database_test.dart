import 'package:drift/drift.dart' hide isNull;
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

void main() {
  late TdbDatabase db;

  setUp(() => db = TdbDatabase.openInMemory());
  tearDown(() => db.close());

  Future<void> addFile([int id = 17]) => db.into(db.gameFiles).insert(
        GameFilesCompanion.insert(
          id: Value(id),
          versionId: 'TEST',
          codec: 'string_table_a',
          lba: 10,
          slotBytes: 4096,
          origBytes: 3000,
        ),
      );

  Future<int> addSource(int fileId, {int table = 0, int slot = 0}) =>
      db.into(db.sourceStrings).insert(
            SourceStringsCompanion.insert(
              fileId: fileId,
              tableIdx: table,
              slotIdx: slot,
              sourceHash: 'ab' * 20,
              sourceText: 'a\nb',
            ),
          );

  test('round-trips a file, a string, a translation and a build', () async {
    await addFile();
    final sid = await addSource(17);
    await db.into(db.translations).insert(
          TranslationsCompanion.insert(
            sourceId: sid,
            locale: 'fr',
            text_: 'x\ny',
            status: 'draft',
          ),
        );
    await db.into(db.builds).insert(
          BuildsCompanion.insert(
            isoMd5: 'a' * 32,
            tdbRevision: 1,
            toolkitVersion: '0.0.1',
            profile: 'strict',
            status: 'ok',
          ),
        );

    final src = await db.select(db.sourceStrings).getSingle();
    expect(src.sourceText, 'a\nb');
    expect(src.aliasOf, isNull);
    final tr = await db.select(db.translations).getSingle();
    expect(tr.text_, 'x\ny');
    expect(tr.revision, 1);
    expect(tr.updatedAt, isA<DateTime>());
    expect((await db.select(db.builds).getSingle()).reportJson, isNull);
  });

  test('unique (file, table, slot) and (source, locale)', () async {
    await addFile();
    final sid = await addSource(17);
    await expectLater(addSource(17), throwsA(isA<Exception>()));
    await addSource(17, slot: 1);

    Future<int> tr(String locale) => db.into(db.translations).insert(
          TranslationsCompanion.insert(
            sourceId: sid,
            locale: locale,
            text_: 't',
            status: 'draft',
          ),
        );
    await tr('fr');
    await expectLater(tr('fr'), throwsA(isA<Exception>()));
    await tr('en');
  });

  test('foreign keys are enforced', () async {
    await expectLater(addSource(999), throwsA(isA<Exception>()));
    await addFile();
    final sid = await addSource(17);
    await expectLater(
      db.into(db.translations).insert(
            TranslationsCompanion.insert(
              sourceId: sid + 100,
              locale: 'fr',
              text_: 't',
              status: 'draft',
            ),
          ),
      throwsA(isA<Exception>()),
    );
    await expectLater(
      db.into(db.sourceStrings).insert(
            SourceStringsCompanion.insert(
              fileId: 17,
              tableIdx: 0,
              slotIdx: 5,
              sourceHash: 'h',
              sourceText: 't',
              aliasOf: Value(sid + 100),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('status accepts the five values only', () async {
    await addFile();
    final sid = await addSource(17);
    var n = 0;
    Future<int> insert(String status) => db.into(db.translations).insert(
          TranslationsCompanion.insert(
            sourceId: sid,
            locale: 'l${n++}',
            text_: 't',
            status: status,
          ),
        );
    for (final s in translationStatuses) {
      await insert(s);
    }
    await expectLater(insert('bogus'), throwsA(isA<Exception>()));
  });

  test('alias_of links to an earlier source string', () async {
    await addFile();
    final a = await addSource(17);
    final b = await db.into(db.sourceStrings).insert(
          SourceStringsCompanion.insert(
            fileId: 17,
            tableIdx: 0,
            slotIdx: 1,
            sourceHash: 'h',
            sourceText: 'a\nb',
            aliasOf: Value(a),
          ),
        );
    final row = await (db.select(db.sourceStrings)
          ..where((t) => t.id.equals(b)))
        .getSingle();
    expect(row.aliasOf, a);
  });
}
