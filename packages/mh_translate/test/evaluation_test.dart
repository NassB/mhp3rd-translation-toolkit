import 'dart:convert';

import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

void main() {
  group('judge', () {
    test('messages carry the pairs and the scoring rules', () {
      final m = buildJudgeMessages(const [
        JudgeItem(id: 3, source: 'こんにちは。', translation: 'Bonjour.'),
      ]);
      expect(m[0].role, 'system');
      expect(m[0].content, contains('de 1 à 5'));
      for (final k in judgeIssueKinds) {
        expect(m[0].content, contains(k));
      }
      final j = (jsonDecode(m[1].content) as Map).cast<String, Object?>();
      expect(j['items'], [
        {'id': 3, 'source': 'こんにちは。', 'translation': 'Bonjour.'},
      ]);
    });

    test('the schema restricts issues to the known kinds', () {
      final schema = judgeSchema().toJson();
      final json = (schema['json_schema']! as Map)['schema']! as Map;
      final item =
          ((json['properties']! as Map)['items']! as Map)['items']! as Map;
      final issues = (item['properties']! as Map)['issues']! as Map;
      expect(
        ((issues['items']! as Map)['enum']! as List).toSet(),
        judgeIssueKinds.toSet(),
      );
      expect(item['required'], ['id', 'score', 'issues']);
    });

    test('parsing keeps valid scores and drops the rest', () {
      final scores = parseJudgeScores(
        'Voici :\n```json\n{"items":['
        '{"id":1,"score":5,"issues":["aucun"]},'
        '{"id":2,"score":"3","issues":["omission","inventé"]},'
        '{"id":3,"score":9,"issues":[]},'
        '{"id":4,"score":2,"issues":[]},'
        '{"id":1,"score":1,"issues":[]},'
        '{"id":99,"score":4,"issues":[]},'
        '"junk"]}\n```',
        [1, 2, 3],
      );
      expect(scores.keys, [1, 2]);
      expect(scores[1]!.score, 5);
      expect(scores[1]!.issues, ['aucun']);
      expect(scores[2]!.score, 3);
      expect(scores[2]!.issues, ['omission']); // motif inconnu écarté
    });

    test('unusable output is an invalid response', () {
      expect(
        () => parseJudgeScores('je ne sais pas', [1]),
        throwsA(isA<TranslateError>()),
      );
    });
  });

  group('back-translation', () {
    test('the prompt goes from French to Japanese', () {
      final m = buildBackTranslationMessages(
        Batch(
          const [TranslationUnit(id: 1, source: 'Bonjour.', maxBytes: 200)],
          0,
        ),
      );
      expect(m[0].content, contains('du français vers le japonais'));
      final j = (jsonDecode(m[1].content) as Map).cast<String, Object?>();
      expect((j['items']! as List).single, containsPair('text', 'Bonjour.'));
    });

    test('round-trip similarity is 1 for identical text, low for unrelated',
        () {
      expect(roundTripSimilarity('こんにちは。', 'こんにちは。'), 1);
      expect(
        roundTripSimilarity('こんにちは。', '薬草を三つ集めてください。'),
        lessThan(0.15),
      );
      final close = roundTripSimilarity('薬草を三つ集めてください。', '薬草を三つ集めて下さい。');
      expect(close, greaterThan(0.3));
    });

    test('PromptOptions defaults keep the Japanese to French direction', () {
      expect(
        systemPrompt(const PromptOptions()),
        contains('du japonais vers le français'),
      );
    });
  });
}
