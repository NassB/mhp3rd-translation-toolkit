import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

Batch batch(List<int> ids) => Batch(
      [
        for (final id in ids)
          TranslationUnit(id: id, source: 'x', maxBytes: 50),
      ],
      0,
    );

void main() {
  group('extractJson', () {
    test('plain, fenced and surrounded JSON', () {
      expect(extractJson('{"a":1}'), {'a': 1});
      expect(extractJson('```json\n{"a":1}\n```'), {'a': 1});
      expect(extractJson('Voici : {"a":[1,2]} Bonne journée.'), {
        'a': [1, 2],
      });
      expect(extractJson('[1,2]'), [1, 2]);
    });

    test('braces inside strings and escapes do not confuse the scan', () {
      expect(extractJson(r'{"t":"a } b \" { c"}'), {'t': 'a } b " { c'});
    });

    test('skips a leading brace that is not JSON; returns null otherwise', () {
      expect(extractJson('{pas du json} puis {"ok":true}'), {'ok': true});
      expect(extractJson('rien du tout'), isNull);
      expect(extractJson('{"coupé":'), isNull);
      expect(extractJson(''), isNull);
    });
  });

  group('parseTranslations', () {
    test('the structured format, with real newlines kept', () {
      final p = parseTranslations(
        '{"items":[{"id":1,"text":"Bonjour."},{"id":2,"text":"Merci\\nbeaucoup."}]}',
        batch([1, 2]),
      );
      expect(p.complete, isTrue);
      expect(p.translations, {1: 'Bonjour.', 2: 'Merci\nbeaucoup.'});
      expect(p.missing, isEmpty);
      expect(p.unexpected, isEmpty);
    });

    test('tolerates fences, a bare array, string ids and "translation"', () {
      final p = parseTranslations(
        'Bien sûr !\n```json\n[{"id":"1","translation":"A"},{"id":2,"text":"B"}]\n```',
        batch([1, 2]),
      );
      expect(p.translations, {1: 'A', 2: 'B'});
    });

    test('reports missing, unexpected and invalid ids without guessing', () {
      final p = parseTranslations(
        '{"items":['
        '{"id":1,"text":"A"},'
        '{"id":9,"text":"intrus"},'
        '{"id":9,"text":"intrus bis"},'
        '{"id":3,"text":42},'
        '{"text":"sans id"},'
        '"junk"]}',
        batch([1, 2, 3]),
      );
      expect(p.translations, {1: 'A'});
      expect(p.missing, [2, 3]);
      expect(p.unexpected, [9]);
      expect(p.invalid, [3]);
      expect(p.complete, isFalse);
    });

    test('the first entry of a duplicated id wins', () {
      final p = parseTranslations(
        '{"items":[{"id":1,"text":"premier"},{"id":1,"text":"second"}]}',
        batch([1]),
      );
      expect(p.translations[1], 'premier');
    });

    test('an empty string is a valid translation', () {
      final p = parseTranslations('{"items":[{"id":1,"text":""}]}', batch([1]));
      expect(p.translations, {1: ''});
      expect(p.complete, isTrue);
    });

    test('unusable output is an invalid response without leaking text', () {
      for (final bad in [
        'désolé, je ne peux pas',
        '{"result":"ok"}',
        '{"items":"pas un tableau"}',
        '',
      ]) {
        expect(
          () => parseTranslations(bad, batch([1])),
          throwsA(
            isA<TranslateError>()
                .having(
                  (e) => e.kind,
                  'kind',
                  TranslateErrorKind.invalidResponse,
                )
                .having((e) => '$e', 'no echo', isNot(contains('désolé'))),
          ),
          reason: bad,
        );
      }
    });

    test('results of ParsedBatch cannot be modified', () {
      final p =
          parseTranslations('{"items":[{"id":1,"text":"a"}]}', batch([1]));
      expect(() => p.translations[2] = 'x', throwsUnsupportedError);
      expect(() => p.missing.add(5), throwsUnsupportedError);
    });
  });
}
