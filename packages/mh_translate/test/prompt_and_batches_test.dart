import 'dart:convert';

import 'package:mh_formats/mh_formats.dart';
import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

TranslationUnit unit(int id, String source, {int maxBytes = 100}) =>
    TranslationUnit(id: id, source: source, maxBytes: maxBytes);

Batch batchOf(List<TranslationUnit> units) => Batch(units, 0);

void main() {
  group('estimateTokens', () {
    test('counts Japanese at 1 token per character, others at 0.35', () {
      expect(estimateTokens(''), 0);
      expect(estimateTokens('こんにちは'), 5);
      expect(estimateTokens('abc'), 2); // ceil(1.05)
      expect(estimateTokens('漢字ABCDEFGHIJ'), 2 + 4);
      expect(estimateTokens('テスト。'), 4); // ponctuation CJK incluse
      expect(estimateTokens('ＡＢ'), 2); // pleine largeur
    });
  });

  group('buildBatches', () {
    test('keeps order, loses nothing, honours maxUnits', () {
      final units = [for (var i = 1; i <= 10; i++) unit(i, 'テキスト$i')];
      final batches = buildBatches(units, maxUnits: 4);
      expect(batches.map((b) => b.units.length), [4, 4, 2]);
      expect(
        batches.expand((b) => b.units).map((u) => u.id),
        [for (var i = 1; i <= 10; i++) i],
      );
    });

    test('honours the token budget and keeps a huge string alone', () {
      final big = unit(2, 'あ' * 500);
      final batches = buildBatches(
        [unit(1, 'ああ'), big, unit(3, 'いい'), unit(4, 'うう')],
        maxBatchTokens: 100,
      );
      expect(batches.map((b) => [for (final u in b.units) u.id]), [
        [1],
        [2],
        [3, 4],
      ]);
      expect(batches[1].estimatedTokens, greaterThan(100));
    });

    test('tokensPerEstimate scales the cost; empty input gives no batch', () {
      final units = [for (var i = 1; i <= 6; i++) unit(i, 'あ' * 20)];
      final normal = buildBatches(units, maxBatchTokens: 200);
      final scaled = buildBatches(
        units,
        maxBatchTokens: 200,
        tokensPerEstimate: 2,
      );
      expect(scaled.length, greaterThan(normal.length));
      expect(buildBatches(const <TranslationUnit>[]), isEmpty);
    });

    test('rejects invalid limits', () {
      expect(
        () => buildBatches([unit(1, 'a')], maxUnits: 0),
        throwsArgumentError,
      );
      expect(
        () => buildBatches([unit(1, 'a')], maxBatchTokens: 0),
        throwsArgumentError,
      );
    });
  });

  group('buildMessages', () {
    Map<String, Object?> userJson(List<ChatMessage> m) =>
        (jsonDecode(m[1].content) as Map).cast<String, Object?>();

    test('the rules ask to keep ~Xnn control codes untouched', () {
      final m = buildMessages(batchOf([unit(1, '~C02あ~C00', maxBytes: 50)]));
      expect(m[0].content, contains('~C00'));
      expect(m[0].content, contains('recopie-les tels quels'));
    });

    test('system rules and a JSON user message with real newlines', () {
      final m = buildMessages(
        batchOf([unit(7, 'ありがとう\nございます。', maxBytes: 40)]),
      );
      expect(m[0].role, 'system');
      expect(m[0].content, contains('japonais vers le français'));
      expect(m[0].content, contains('sauts de ligne'));
      expect(m[0].content, contains('octets UTF-8'));
      expect(m[1].role, 'user');
      final j = userJson(m);
      expect(j['items'], [
        {'id': 7, 'text': 'ありがとう\nございます。', 'max_bytes': 40},
      ]);
      expect(j.containsKey('glossary'), isFalse);
      expect(j.containsKey('context_before'), isFalse);
      // Jamais les marqueurs mhtools.
      expect(m[1].content, isNot(contains('<NEWLINE>')));
    });

    test('options change the language, the game and add rules', () {
      final m = buildMessages(
        batchOf([unit(1, 'a')]),
        options: const PromptOptions(
          targetLanguage: 'anglais',
          gameContext: 'un jeu de test',
          extraRules: ['Tutoie le joueur.'],
        ),
      );
      expect(m[0].content, contains('japonais vers le anglais'));
      expect(m[0].content, contains('un jeu de test'));
      expect(m[0].content, endsWith('Tutoie le joueur.'));
    });

    test('only matching glossary terms are sent, mandatory ones first', () {
      const glossary = [
        GlossaryEntry(sourceTerm: 'ハンター', targetTerm: 'Chasseur'),
        GlossaryEntry(
          sourceTerm: 'リオレウス',
          targetTerm: 'Rathalos',
          mandatory: true,
        ),
        GlossaryEntry(sourceTerm: 'アイルー', targetTerm: 'Felyne'),
      ];
      final m = buildMessages(
        batchOf([unit(1, 'ハンターはリオレウスを倒す。')]),
        context: const BatchContext(glossary: glossary),
      );
      expect(userJson(m)['glossary'], [
        {'source': 'リオレウス', 'target': 'Rathalos', 'mandatory': true},
        {'source': 'ハンター', 'target': 'Chasseur'},
      ]);
    });

    test('neighbour context and fix hints are included only when given', () {
      final m = buildMessages(
        batchOf([unit(1, 'あ'), unit(2, 'い')]),
        context: const BatchContext(
          before: ['前の文'],
          after: ['次の文'],
          corrections: {2: '1 saut de ligne attendu'},
        ),
      );
      final j = userJson(m);
      expect(j['context_before'], ['前の文']);
      expect(j['context_after'], ['次の文']);
      final items = (j['items']! as List).cast<Map<String, Object?>>();
      expect(items[0].containsKey('fix'), isFalse);
      expect(items[1]['fix'], '1 saut de ligne attendu');
      // L'ordre : contexte avant, éléments, contexte après.
      expect(j.keys.toList(), ['context_before', 'items', 'context_after']);
    });
  });

  test('translationSchema describes {"items":[{"id","text"}]}', () {
    final f = translationSchema();
    expect(f.name, 'translations');
    expect(f.strict, isTrue);
    final json = f.toJson();
    expect(json['type'], 'json_schema');
    final schema = (json['json_schema']! as Map)['schema']! as Map;
    expect(schema['required'], ['items']);
    final item =
        ((schema['properties']! as Map)['items']! as Map)['items']! as Map;
    expect(item['required'], ['id', 'text']);
    expect(item['additionalProperties'], isFalse);
  });
}
