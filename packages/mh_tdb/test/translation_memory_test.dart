import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

typedef Pair = ({int id, String source, String target});
Pair p(int id, String source, String target) =>
    (id: id, source: source, target: target);

void main() {
  group('trigrams and similarity', () {
    test('trigrams are padded like pg_trgm, case-insensitive, rune based', () {
      // "  a" " ab" "ab " pour « ab ».
      expect(trigrams('ab'), hasLength(3));
      expect(trigrams('AB'), trigrams('ab'));
      expect(trigrams(''), isEmpty);
      // 2 points de code hors BMP comptent pour 2, pas 4.
      expect(trigrams('😀😀'), hasLength(3));
    });

    test('similarity is 1 for equal texts and 0 for disjoint ones', () {
      expect(similarity('リオレウス', 'リオレウス'), 1);
      expect(similarity('abc', 'xyz'), 0);
      expect(similarity('', ''), 0);
      final s = similarity('Grande Épée', 'Grande Epee');
      expect(s, greaterThan(0.2));
      expect(s, lessThan(1));
      expect(similarity('abc', 'abd'), similarity('abd', 'abc'));
    });
  });

  group('suggest', () {
    final tm = TranslationMemory.fromPairs([
      p(1, 'リオレウスを討伐せよ', 'Tuez le Rathalos'),
      p(2, 'リオレウスを討伐せよ!', 'Tuez le Rathalos !'),
      p(3, 'アイルーを助けよ', 'Aidez le Felyne'),
      p(4, 'まったく別の文章', 'Une autre phrase'),
      p(5, '', 'vide'),
    ]);

    test('an exact source comes first with score 1', () {
      final m = tm.suggest('リオレウスを討伐せよ');
      expect(m.first.exact, isTrue);
      expect(m.first.score, 1);
      expect(m.first.targetText, 'Tuez le Rathalos');
      expect(m[1].exact, isFalse);
      expect(m[1].sourceId, 2);
      expect(m[1].score, lessThan(1));
    });

    test('exact ignores edge whitespace; the current string can be excluded',
        () {
      expect(tm.suggest('  リオレウスを討伐せよ \n').first.sourceId, 1);
      final withoutSelf = tm.suggest('リオレウスを討伐せよ', excludeSourceId: 1);
      expect(withoutSelf.map((m) => m.sourceId), [2]);
    });

    test('minScore and limit are honoured; unrelated texts are not returned',
        () {
      final strict = tm.suggest('リオレウスを討伐せよ', minScore: 0.99);
      expect(strict.map((m) => m.sourceId), [1]);
      expect(tm.suggest('リオレウスを討伐せよ', limit: 1), hasLength(1));
      expect(tm.suggest('全然関係ない'), isEmpty);
      expect(tm.suggest(''), isEmpty);
      expect(tm.suggest('   '), isEmpty);
    });

    test('empty sources are not indexed', () {
      expect(tm.length, 4);
    });

    test('ties go to the more reviewed translation', () {
      final reviewed = TranslationMemory.fromPairs([p(1, 'abcdef', 'A')]);
      expect(reviewed.suggest('abcdef').single.targetText, 'A');
    });
  });

  group('load from the database', () {
    late TdbDatabase db;
    late TranslationRepository repo;

    StringTableFile file(List<String> lines) => StringTableFile(
          unknownHeader: 0,
          tables: [
            StringTable(
              originalOffsets: const [],
              slots: [
                for (var i = 0; i < lines.length; i++)
                  StringSlot(index: i, raw: b(lines[i])),
                StringSlot(index: lines.length, raw: b(lines[0]), aliasOf: 0),
              ],
            ),
          ],
          endData: Uint8List(0),
        );

    setUp(() async {
      db = TdbDatabase.openInMemory();
      repo = TranslationRepository(db, locale: 'fr');
      await importSourceFile(
        db,
        fileId: 1,
        versionId: 'T',
        lba: 1,
        slotBytes: 2048,
        origBytes: 2048,
        file: file(['Quête du dragon', 'Quête du dragon rouge', 'Marché']),
      );
    });
    tearDown(() => db.close());

    Future<void> save(int slot, String text, String status) async {
      final s = (await repo.slots(1))[slot];
      await repo.saveTranslation(
        sourceId: s.sourceId,
        text: text,
        status: status,
      );
    }

    test('only translations of the requested level and locale are indexed',
        () async {
      await save(0, 'Dragon quest', 'translated');
      await save(1, 'Red dragon quest', 'draft'); // ébauche : exclue par défaut
      await save(2, '', 'translated'); // texte vide : exclu
      final tm = await TranslationMemory.load(db, locale: 'fr');
      expect(tm.length, 1);
      expect((await TranslationMemory.load(db, locale: 'en')).length, 0);
      expect(
        (await TranslationMemory.load(db, locale: 'fr', minStatus: 'draft'))
            .length,
        2,
      );
      expect(
        (await TranslationMemory.load(db, locale: 'fr', minStatus: 'reviewed'))
            .length,
        0,
      );
    });

    test('aliases are not indexed and suggestions come from saved work',
        () async {
      await save(0, 'Dragon quest', 'translated');
      final tm = await TranslationMemory.load(db, locale: 'fr');
      final slots = await repo.slots(1);
      final m = tm.suggest(
        slots[1].sourceText, // « Quête du dragon rouge »
        excludeSourceId: slots[1].sourceId,
      );
      expect(m.single.targetText, 'Dragon quest');
      expect(m.single.exact, isFalse);
      expect(m.single.fileId, 1);
      expect(m.single.slotIdx, 0);
    });

    test('an unknown status is rejected', () async {
      await expectLater(
        TranslationMemory.load(db, locale: 'fr', minStatus: 'bogus'),
        throwsA(isA<TdbError>()),
      );
    });
  });
}
