import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

int bytes(String s) => utf8.encode(s).length;

const sources = [
  'こんにちは。',
  'ありがとう\nございます。',
  '~C02ネットワーク終了まで\n電源を切ったり、記録メディアを\n抜き差ししないでください。~C00',
  '現在、記録メディアに\n%s個のクエストデータが\n保存されています。',
  '『モンスターハンターポータブル　３ｒｄ』からの\n引き継ぎを行います。~B00ボタンを押してください。',
  'ア',
  '\n',
];

final _codes = RegExp(r'~[A-Za-z][0-9A-Za-z]{2}|%[sd]');

void main() {
  group('calibrationText', () {
    test('is never longer than the source and keeps its structure', () {
      for (final s in sources) {
        for (var slot = 0; slot < 16; slot++) {
          final t = calibrationText(s, number: slot);
          expect(bytes(t), lessThanOrEqualTo(bytes(s)), reason: '$s $slot');
          expect('\n'.allMatches(t).length, '\n'.allMatches(s).length);
          expect(
            [for (final m in _codes.allMatches(t)) m.group(0)],
            [for (final m in _codes.allMatches(s)) m.group(0)],
          );
          // Pas d'erreur de linter : codes et sauts de ligne identiques.
          expect(
            lintTranslation(source: s, target: t)
                .where((i) => i.severity == LintSeverity.error),
            isEmpty,
          );
        }
      }
    });

    test('carries its tag, then the pattern', () {
      final long = 'あ' * 30; // 90 octets
      final t = calibrationText(long, number: 16); // ruler
      expect(t, startsWith('[#16]012345678a012345678b'));
      expect(bytes(t), 90);
      final narrow = calibrationText(long, number: 1);
      expect(narrow, '[#1]${'i' * 86}');
    });

    test('the ruler marks every tenth character with a letter', () {
      final t = calibrationText('あ' * 40, number: 0);
      final ruler = t.substring('[#0]'.length);
      expect(ruler.substring(0, 30), '012345678a012345678b012345678c');
    });

    test('accents fill whole characters only', () {
      final t = calibrationText('あ' * 10, number: 5); // accents
      expect(t, startsWith('[#5]'));
      expect(bytes(t), lessThanOrEqualTo(30));
      expect(() => utf8.encode(t), returnsNormally);
      expect(t.substring(4), matches(RegExp(r'^[éèêëàâùûôîïçÉÈÀÇ]+$')));
    });

    test('a string too short for its tag is left as it is', () {
      expect(calibrationText('ア', number: 12345), 'ア');
      expect(calibrationText('\n', number: 0), '\n');
    });

    test('codes, newlines and format markers stay in place', () {
      final s = '~C02あいうえおかきくけこ\nさしすせそたちつてと%dなにぬ~C00';
      final t = calibrationText(s, number: 4);
      final parts = t.split(RegExp(r'~C02|~C00|\n|%d'));
      expect(parts.length, s.split(RegExp(r'~C02|~C00|\n|%d')).length);
      expect(t, startsWith('~C02[#4]'));
      expect(t, contains('\n'));
      expect(t, endsWith('~C00'));
    });

    test('is deterministic', () {
      for (final s in sources) {
        expect(
          calibrationText(s, number: 7),
          calibrationText(s, number: 7),
        );
      }
    });
  });

  group('applyCalibration', () {
    late TdbDatabase db;
    late TranslationRepository repo;

    setUp(() async {
      db = TdbDatabase.openInMemory();
      repo = TranslationRepository(db, locale: 'calib');
      await importSourceFile(
        db,
        fileId: 17,
        versionId: 'T',
        lba: 1,
        slotBytes: 4096,
        origBytes: 4096,
        file: StringTableFile(
          unknownHeader: 0,
          tables: [
            StringTable(
              originalOffsets: const [],
              slots: [
                StringSlot(index: 0, raw: b('こんにちは、世界のみなさん。')),
                StringSlot(index: 1, raw: b('~C02ありがとう\nございます。~C00')),
                StringSlot(index: 2, raw: b('%d')),
                StringSlot(index: 3, raw: b('ア')),
                StringSlot(index: 4, raw: b('こんにちは、世界のみなさん。'), aliasOf: 0),
              ],
            ),
          ],
          endData: Uint8List(0),
        ),
      );
    });
    tearDown(() => db.close());

    test('saves translated calibration text and reports without game text',
        () async {
      final r = await applyCalibration(repo: repo, fileId: 17);
      expect(r.rows.map((x) => '${x.tableIdx}.${x.slotIdx}'), ['0.0', '0.1']);
      expect(r.untouched, 3); // %d sans japonais, trop court, alias
      expect(r.deltaBytes, lessThanOrEqualTo(0));
      final slots = await repo.slots(17);
      final s0 = slots.firstWhere((s) => s.slotIdx == 0);
      expect(s0.translation!.status, 'translated');
      expect(s0.translation!.authorId, calibrationAuthor);
      expect(s0.translation!.text, startsWith('[#1]'));
      final md = calibrationMarkdown(r);
      expect(md, contains('| [#2] | 0.1 | wide |'));
      expect(md, contains('**ruler**'));
      expect(RegExp(r'[぀-ヿ㐀-鿿]').hasMatch(md), isFalse);
    });

    test('is repeatable', () async {
      await applyCalibration(repo: repo, fileId: 17);
      final again = await applyCalibration(repo: repo, fileId: 17);
      expect(again.rows, hasLength(2));
      final s = (await repo.slots(17)).firstWhere((x) => x.slotIdx == 0);
      expect(s.translation!.revision, 2);
    });

    test('refuses to overwrite real translations unless forced', () async {
      final s = (await repo.slots(17)).firstWhere((x) => x.slotIdx == 0);
      await repo.saveTranslation(
        sourceId: s.sourceId,
        text: 'Bonjour.',
        status: 'translated',
      );
      await expectLater(
        applyCalibration(repo: repo, fileId: 17),
        throwsA(isA<TdbError>()),
      );
      final r = await applyCalibration(repo: repo, fileId: 17, force: true);
      expect(r.rows, hasLength(2));
    });
  });
}
