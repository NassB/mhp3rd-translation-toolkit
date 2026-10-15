import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:sqlite3/sqlite3.dart' as raw;
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

StringTableFile sample() => StringTableFile(
      unknownHeader: 0,
      tables: [
        StringTable(
          originalOffsets: const [],
          slots: [
            StringSlot(index: 0, raw: b('a')),
            StringSlot(index: 1, raw: b('b')),
          ],
        ),
      ],
      endData: Uint8List(0),
    );

Future<void> importSample(TdbDatabase db) => importSourceFile(
      db,
      fileId: 17,
      versionId: 'TEST',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: sample(),
    );

void main() {
  group('history', () {
    late TdbDatabase db;
    late TranslationRepository repo;
    setUp(() async {
      db = TdbDatabase.openInMemory();
      repo = TranslationRepository(db, locale: 'fr');
      await importSample(db);
    });
    tearDown(() => db.close());

    test('every accepted save appends a revision, newest first', () async {
      final id = (await repo.slots(17)).first.sourceId;
      expect(await repo.history(id), isEmpty);
      await repo.saveTranslation(
        sourceId: id,
        text: 'A',
        status: 'draft',
        authorId: 'u1',
      );
      await repo.saveTranslation(
        sourceId: id,
        text: 'A2',
        status: 'translated',
        expectedRevision: 1,
      );
      // Conflit : rien n'est ajouté.
      await repo.saveTranslation(
        sourceId: id,
        text: 'x',
        status: 'draft',
        expectedRevision: 1,
      );
      final h = await repo.history(id);
      expect(h.map((r) => (r.revision, r.text, r.status)), [
        (2, 'A2', 'translated'),
        (1, 'A', 'draft'),
      ]);
      expect(h.last.authorId, 'u1');
      expect(
        await TranslationRepository(db, locale: 'en').history(id),
        isEmpty,
      );
    });

    test('mhtools import records created and updated revisions', () async {
      final original = sample();
      Future<int> run(String l, {String status = 'draft'}) =>
          importMhtoolsTranslations(
            db,
            fileId: 17,
            original: original,
            dump: MhtoolsDump(
              fileListText: '',
              tableTexts: ['$l\nb\n'],
              endData: Uint8List(0),
            ),
            locale: 'fr',
            status: status,
          );
      await run('A');
      await run('A'); // inchangé : pas de révision
      await run('B', status: 'translated');
      final id = (await repo.slots(17)).first.sourceId;
      final h = await repo.history(id);
      expect(h.map((r) => (r.revision, r.text)), [(2, 'B'), (1, 'A')]);
    });
  });

  group('glossary', () {
    late TdbDatabase db;
    late GlossaryRepository g;
    setUp(() {
      db = TdbDatabase.openInMemory();
      g = GlossaryRepository(db, locale: 'fr');
    });
    tearDown(() => db.close());

    test('add, list, update, delete', () async {
      final id = await g.add(
        sourceTerm: 'リオレウス',
        targetTerm: 'Rathalos',
        mandatory: true,
      );
      await g.add(sourceTerm: 'ハンター', targetTerm: 'Chasseur', note: 'n');
      final all = await g.all();
      expect(all, hasLength(2));
      expect(all.firstWhere((t) => t.id == id).mandatory, isTrue);

      await g.update(id, targetTerm: 'Rathalos (roi)', mandatory: false);
      final u = (await g.all()).firstWhere((t) => t.id == id);
      expect(
        (u.targetTerm, u.mandatory, u.note),
        ('Rathalos (roi)', false, null),
      );

      await g.delete(id);
      expect(await g.all(), hasLength(1));
    });

    test('rejects duplicates, empties and unknown ids; isolates locales',
        () async {
      await g.add(sourceTerm: 'a', targetTerm: 'A');
      await expectLater(
        g.add(sourceTerm: 'a', targetTerm: 'B'),
        throwsA(isA<TdbError>()),
      );
      await expectLater(
        g.add(sourceTerm: ' ', targetTerm: 'B'),
        throwsA(isA<TdbError>()),
      );
      await expectLater(
        g.add(sourceTerm: 'z', targetTerm: ''),
        throwsA(isA<TdbError>()),
      );
      await expectLater(
        g.update(999, targetTerm: 'x', mandatory: false),
        throwsA(isA<TdbError>()),
      );
      await expectLater(g.delete(999), throwsA(isA<TdbError>()));
      final en = GlossaryRepository(db, locale: 'en');
      await en.add(sourceTerm: 'a', targetTerm: 'A-en'); // autre locale : ok
      expect(await en.all(), hasLength(1));
      expect(await g.all(), hasLength(1));
      await expectLater(
        en.delete((await g.all()).single.id),
        throwsA(isA<TdbError>()),
      );
    });

    test('termsFoundIn returns the terms present in a source text', () async {
      await g.add(sourceTerm: 'リオレウス', targetTerm: 'Rathalos');
      await g.add(sourceTerm: 'ハンター', targetTerm: 'Chasseur');
      final found = await g.termsFoundIn('リオレウスを倒せ');
      expect(found.map((t) => t.targetTerm), ['Rathalos']);
      expect(await g.termsFoundIn('rien'), isEmpty);
    });
  });

  test('a v1 database is migrated: new tables, history backfilled', () async {
    final dir = Directory.systemTemp.createTempSync('mh_tdb_migrate');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/tdb.sqlite';

    var db = TdbDatabase.openFile(path);
    await importSample(db);
    final repo = TranslationRepository(db, locale: 'fr');
    final id = (await repo.slots(17)).first.sourceId;
    await repo.saveTranslation(sourceId: id, text: 'A', status: 'draft');
    await repo.saveTranslation(
      sourceId: id,
      text: 'A2',
      status: 'draft',
      expectedRevision: 1,
    );
    await db.close();

    // Ramène le fichier à l'état v1 : sans les tables v2, user_version = 1.
    final sqlite = raw.sqlite3.open(path)
      ..execute('DROP TABLE translation_history')
      ..execute('DROP TABLE glossary_term')
      ..execute('PRAGMA user_version = 1');
    sqlite.dispose();

    db = TdbDatabase.openFile(path);
    addTearDown(db.close);
    final h = await TranslationRepository(db, locale: 'fr').history(id);
    expect(h.map((r) => (r.revision, r.text)), [(2, 'A2')]);
    expect(await GlossaryRepository(db, locale: 'fr').all(), isEmpty);
    await GlossaryRepository(db, locale: 'fr')
        .add(sourceTerm: 'x', targetTerm: 'y');
  });
}
