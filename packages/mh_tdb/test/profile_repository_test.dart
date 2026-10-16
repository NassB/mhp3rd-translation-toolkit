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
  late ProfileRepository repo;
  late TranslationRepository tr;
  const known = {'menu_label', 'dialogue'};

  setUp(() async {
    db = TdbDatabase.openInMemory();
    repo = ProfileRepository(db);
    tr = TranslationRepository(db, locale: 'fr');
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'T',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: sample(),
    );
  });
  tearDown(() => db.close());

  Future<int> idOf(int table, int slot) async => (await tr.slots(17))
      .firstWhere((s) => s.tableIdx == table && s.slotIdx == slot)
      .sourceId;

  test('nothing is assigned at first', () async {
    expect(await repo.fileProfile(17), isNull);
    expect(await repo.countByProfile(17), {null: 3});
  });

  test('a file profile is the default of its strings', () async {
    await repo.setFileProfile(17, 'dialogue', knownIds: known);
    expect(await repo.fileProfile(17), 'dialogue');
    expect(await repo.effectiveProfile(await idOf(2, 0)), 'dialogue');
    expect(await repo.countByProfile(17), {'dialogue': 3});
    await repo.setFileProfile(17, null);
    expect(await repo.countByProfile(17), {null: 3});
  });

  test('a table profile covers its non-alias strings and overrides the file',
      () async {
    await repo.setFileProfile(17, 'dialogue');
    final n = await repo.setTableProfile(17, 0, 'menu_label', knownIds: known);
    expect(n, 2); // the alias is excluded
    expect(await repo.countByProfile(17), {'menu_label': 2, 'dialogue': 1});
    expect(await repo.effectiveProfile(await idOf(0, 1)), 'menu_label');
    await repo.setTableProfile(17, 0, null);
    expect(await repo.countByProfile(17), {'dialogue': 3});
  });

  test('a string profile overrides its table', () async {
    await repo.setTableProfile(17, 0, 'menu_label');
    await repo.setStringProfile(await idOf(0, 1), 'dialogue');
    final m = await repo.effectiveProfiles(17);
    expect(m[await idOf(0, 0)], 'menu_label');
    expect(m[await idOf(0, 1)], 'dialogue');
    expect(m[await idOf(2, 0)], isNull);
    expect(m.length, 3); // no alias
  });

  test('unknown profiles, files, tables, aliases and empty ids are rejected',
      () async {
    final alias = (await tr.slots(17)).firstWhere((s) => s.isAlias).sourceId;
    for (final call in [
      () => repo.setFileProfile(17, 'nope', knownIds: known),
      () => repo.setTableProfile(17, 0, 'nope', knownIds: known),
      () => repo.setStringProfile(alias, 'dialogue'),
      () => repo.setStringProfile(99999, 'dialogue'),
      () => repo.setFileProfile(99, 'dialogue'),
      () => repo.setTableProfile(17, 1, 'dialogue'), // null table
      () => repo.setFileProfile(17, ' '),
      () => repo.fileProfile(99),
      () => repo.effectiveProfile(99999),
    ]) {
      await expectLater(call(), throwsA(isA<TdbError>()));
    }
    expect(await repo.countByProfile(17), {null: 3});
  });
}
