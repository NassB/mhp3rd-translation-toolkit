import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

class FakeClient implements ChatClient {
  FakeClient(this.reply);
  final String Function(List<ChatMessage>) reply;
  final calls = <List<ChatMessage>>[];

  @override
  Future<ChatResult> chat({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    JsonSchemaFormat? jsonSchema,
  }) async {
    calls.add(messages);
    return ChatResult(content: reply(messages), finishReason: 'stop');
  }

  @override
  Future<List<String>> listModels() async => ['m'];
}

void main() {
  group('termRuns', () {
    test('finds katakana and kanji runs, not hiragana or short runs', () {
      expect(
        termRuns('リオレウスを狩る。火竜の素材とアイテム'),
        {'リオレウス', '火竜', '素材', 'アイテム'},
      );
      expect(termRuns('ひらがなだけ'), isEmpty);
      expect(termRuns('カメ 木'), isEmpty); // trop courts
    });

    test('a leading long-vowel mark does not start a run', () {
      expect(termRuns('ーアイテム'), {'アイテム'});
    });

    test('keeps the long-vowel mark inside a run', () {
      expect(termRuns('ポーション'), {'ポーション'});
    });

    test('overlong runs are dropped', () {
      expect(termRuns('ア' * 40), isEmpty);
    });
  });

  group('extractTermCandidates', () {
    final sources = [
      'リオレウスを倒せ',
      'リオレウスの素材',
      'リオレウスと火竜',
      '火竜の卵',
      '火竜が来た',
      'アイテムを使う',
    ];

    test('counts strings, applies the threshold and ranks by count × length',
        () {
      final c = extractTermCandidates(sources, minCount: 2);
      expect([for (final x in c) x.term], ['リオレウス', '火竜']);
      expect(c.first.count, 3);
      expect(c.first.example, 'リオレウスを倒せ');
    });

    test('a term counts once per string', () {
      final c = extractTermCandidates(['リオレウスリオレウス'], minCount: 2);
      expect(c, isEmpty);
    });

    test('known terms are excluded and limit applies', () {
      final c = extractTermCandidates(
        sources,
        minCount: 2,
        known: {'リオレウス'},
      );
      expect([for (final x in c) x.term], ['火竜']);
      expect(
        extractTermCandidates(sources, minCount: 2, limit: 1),
        hasLength(1),
      );
    });
  });

  group('model proposals', () {
    final cands = [
      const TermCandidate(term: 'リオレウス', count: 3, example: 'リオレウスを倒せ'),
      const TermCandidate(term: '火竜', count: 2, example: '火竜が来た'),
    ];

    test('messages carry term and example only', () {
      final m = buildTermMessages(cands);
      final j = (jsonDecode(m[1].content) as Map).cast<String, Object?>();
      expect(j['items'], [
        {'id': 0, 'term': 'リオレウス', 'example': 'リオレウスを倒せ'},
        {'id': 1, 'term': '火竜', 'example': '火竜が来た'},
      ]);
    });

    test('long examples are clipped', () {
      final m = buildTermMessages([
        TermCandidate(term: 'ハンター', count: 3, example: 'あ' * 500),
      ]);
      final item =
          ((jsonDecode(m[1].content) as Map)['items'] as List).single as Map;
      expect((item['example'] as String).runes.length, 120);
    });

    test('parsing drops invalid, empty, duplicate and unknown ids', () {
      final out = parseTermTranslations(
        '```json\n{"items":[{"id":0,"translation":" Rathalos "},'
        '{"id":1,"translation":"  "},{"id":0,"translation":"x"},'
        '{"id":7,"translation":"y"},{"id":"1","translation":"Wyvern de feu"}]}'
        '\n```',
        2,
      );
      expect(out, {0: 'Rathalos', 1: 'Wyvern de feu'});
    });

    test('parsing without JSON is an invalidResponse without echo', () {
      expect(
        () => parseTermTranslations('secret リオレウス', 2),
        throwsA(
          isA<TranslateError>()
              .having((e) => e.kind, 'kind', TranslateErrorKind.invalidResponse)
              .having((e) => e.message, 'message', isNot(contains('secret'))),
        ),
      );
    });

    test('proposals are batched and mapped back to terms', () async {
      final many = [
        for (var i = 0; i < 5; i++)
          TermCandidate(term: 'タ$i' 'ーム', count: 3, example: 'e$i'),
      ];
      final client = FakeClient((m) {
        final items = (jsonDecode(m[1].content) as Map)['items'] as List;
        return jsonEncode({
          'items': [
            for (final it in items)
              {'id': (it as Map)['id'], 'translation': 'T-${it['term']}'},
          ],
        });
      });
      final out = await proposeTermTranslations(
        client: client,
        model: 'm',
        candidates: many,
        batchSize: 2,
      );
      expect(client.calls, hasLength(3));
      expect(out.length, 5);
      expect(out[many[4].term], 'T-${many[4].term}');
    });

    test('cancellation stops before the next batch', () async {
      final many = [
        for (var i = 0; i < 4; i++)
          TermCandidate(term: 'ター$i', count: 3, example: 'e'),
      ];
      var stop = false;
      final client = FakeClient((m) {
        stop = true;
        return '{"items":[]}';
      });
      await proposeTermTranslations(
        client: client,
        model: 'm',
        candidates: many,
        batchSize: 2,
        isCancelled: () => stop,
      );
      expect(client.calls, hasLength(1));
    });
  });

  test('projectTermCandidates reads non-alias strings and skips known terms',
      () async {
    final db = TdbDatabase.openInMemory();
    addTearDown(db.close);
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'T',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: StringTableFile(
        unknownHeader: 0,
        tables: [
          StringTable(
            originalOffsets: const [],
            slots: [
              StringSlot(index: 0, raw: b('リオレウスを倒せ')),
              StringSlot(index: 1, raw: b('リオレウスの素材')),
              StringSlot(index: 2, raw: b('リオレウスを倒せ'), aliasOf: 0),
              StringSlot(index: 3, raw: b('ランゴスタ')),
            ],
          ),
        ],
        endData: Uint8List(0),
      ),
    );
    final repo = TranslationRepository(db, locale: 'fr');
    final glossary = GlossaryRepository(db, locale: 'fr');
    final c = await projectTermCandidates(
      repo: repo,
      glossary: glossary,
      minCount: 2,
    );
    expect([for (final x in c) x.term], ['リオレウス']);
    expect(c.single.count, 2); // l'alias n'est pas compté
    await glossary.add(sourceTerm: 'リオレウス', targetTerm: 'Rathalos');
    expect(
      await projectTermCandidates(repo: repo, glossary: glossary, minCount: 2),
      isEmpty,
    );
  });
}
