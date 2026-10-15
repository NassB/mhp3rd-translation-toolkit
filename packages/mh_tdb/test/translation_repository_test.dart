import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

// Fichier 17 : table 0 = 'a', 'b', alias de 0 ; table 1 nulle ; table 2 = 'c'.
StringTableFile sample() => StringTableFile(
      unknownHeader: 0,
      tables: [
        StringTable(
          originalOffsets: const [],
          slots: [
            StringSlot(index: 0, raw: b('a')),
            StringSlot(index: 1, raw: b('b')),
            StringSlot(index: 2, raw: b('a'), aliasOf: 0),
          ],
        ),
        null,
        StringTable(
          originalOffsets: const [],
          slots: [StringSlot(index: 0, raw: b('c'))],
        ),
      ],
      endData: Uint8List(0),
    );

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;

  setUp(() async {
    db = TdbDatabase.openInMemory();
    repo = TranslationRepository(db, locale: 'fr');
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'TEST',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      label: 'demo',
      file: sample(),
    );
  });
  tearDown(() => db.close());

  Future<List<SlotView>> all() => repo.slots(17);
  Future<int> idOf(int table, int slot) async => (await all())
      .firstWhere((s) => s.tableIdx == table && s.slotIdx == slot)
      .sourceId;

  test('listFiles counts non-alias strings, untranslated by default', () async {
    final files = await repo.listFiles();
    expect(files, hasLength(1));
    final f = files.single;
    expect((f.id, f.label, f.slotBytes), (17, 'demo', 2048));
    expect(f.totalStrings, 3); // 4 slots dont 1 alias
    expect(f.byStatus['untranslated'], 3);
    expect(f.doneStrings, 0);
  });

  test('listFiles follows saved statuses, per locale', () async {
    await repo.saveTranslation(
      sourceId: await idOf(0, 0),
      text: 'A',
      status: 'translated',
    );
    await repo.saveTranslation(
      sourceId: await idOf(0, 1),
      text: 'B',
      status: 'draft',
    );
    await TranslationRepository(db, locale: 'en').saveTranslation(
      sourceId: await idOf(2, 0),
      text: 'C',
      status: 'locked',
    );
    final f = (await repo.listFiles()).single;
    expect(f.byStatus['translated'], 1);
    expect(f.byStatus['draft'], 1);
    expect(f.byStatus['untranslated'], 1);
    expect(f.byStatus['locked'], 0);
    expect(f.doneStrings, 1);
  });

  test('slots are ordered, paged, and expose aliases', () async {
    expect(await repo.countSlots(17), 4);
    final first = await repo.slots(17, limit: 3);
    expect(first.map((s) => (s.tableIdx, s.slotIdx)), [(0, 0), (0, 1), (0, 2)]);
    expect(first[2].isAlias, isTrue);
    expect(first[2].aliasOfSlot, 0);
    expect(first[0].isAlias, isFalse);
    expect(first[0].sourceText, 'a');
    expect(first[0].translation, isNull);
    final rest = await repo.slots(17, offset: 3, limit: 3);
    expect(rest.map((s) => (s.tableIdx, s.slotIdx)), [(2, 0)]);
    expect(await repo.slots(99), isEmpty);
  });

  test('save creates then updates with optimistic concurrency', () async {
    final id = await idOf(0, 0);
    final created = await repo.saveTranslation(
      sourceId: id,
      text: 'A',
      status: 'draft',
      authorId: 'u1',
    );
    final t1 = (created as SaveOk).translation;
    expect(t1.text, 'A');
    expect(t1.status, 'draft');
    expect(t1.revision, 1);
    expect(t1.authorId, 'u1');

    final updated = await repo.saveTranslation(
      sourceId: id,
      text: 'A2',
      status: 'translated',
      expectedRevision: 1,
    );
    final t2 = (updated as SaveOk).translation;
    expect((t2.text, t2.revision), ('A2', 2));
    expect(t2.id, t1.id);

    final stale = await repo.saveTranslation(
      sourceId: id,
      text: 'zzz',
      status: 'draft',
      expectedRevision: 1,
    );
    expect((stale as SaveConflict).current!.text, 'A2');

    final again = await repo.saveTranslation(
      sourceId: id,
      text: 'zzz',
      status: 'draft',
    );
    expect((again as SaveConflict).current!.revision, 2);

    final view = (await all()).firstWhere((s) => s.sourceId == id);
    expect(view.translation!.text, 'A2');
  });

  test('update of a vanished row is a conflict with no current', () async {
    final r = await repo.saveTranslation(
      sourceId: await idOf(0, 1),
      text: 'x',
      status: 'draft',
      expectedRevision: 3,
    );
    expect((r as SaveConflict).current, isNull);
  });

  test('rejects aliases, unknown sources, statuses and NUL', () async {
    final alias = (await all()).firstWhere((s) => s.isAlias).sourceId;
    final ok = await idOf(0, 0);
    Future<SaveResult> save(int id, {String text = 't', String st = 'draft'}) =>
        repo.saveTranslation(sourceId: id, text: text, status: st);
    await expectLater(save(alias), throwsA(isA<TdbError>()));
    await expectLater(save(9999), throwsA(isA<TdbError>()));
    await expectLater(save(ok, st: 'bogus'), throwsA(isA<TdbError>()));
    await expectLater(save(ok, text: 'a\u0000'), throwsA(isA<TdbError>()));
    expect(await db.select(db.translations).get(), isEmpty);
  });
}
