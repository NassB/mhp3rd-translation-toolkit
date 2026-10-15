// ignore_for_file: type=lint
// Contrôle local (TA4) : le moteur complet contre LM Studio sur une base en
// mémoire de phrases japonaises SYNTHÉTIQUES (jamais du texte du jeu).
import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

Future<void> main(List<String> a) async {
  const lines = [
    'こんにちは。',
    'ありがとう\nございます。',
    'ハンターは森へ行く。',
    'お水をください。',
    'これはペンです。',
    'さようなら',
    '今日は天気がいいですね。',
    '武器を持っていますか？',
    '薬草を三つ集めてください。',
    '村に帰りましょう。',
    '夜になると危険です。',
    '準備はいいですか？',
  ];
  final db = TdbDatabase.openInMemory();
  final repo = TranslationRepository(db, locale: 'fr');
  final glossary = GlossaryRepository(db, locale: 'fr');
  await importSourceFile(db,
      fileId: 1,
      versionId: 'T',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: StringTableFile(
          unknownHeader: 0,
          tables: [
            StringTable(originalOffsets: const [], slots: [
              for (var i = 0; i < lines.length; i++)
                StringSlot(index: i, raw: b(lines[i])),
            ]),
          ],
          endData: Uint8List(0)));
  await glossary.add(
      sourceTerm: 'ハンター', targetTerm: 'Chasseur', mandatory: true);
  final client = OpenAiCompatibleClient(endpoint: Uri.parse(a[0]));
  final sw = Stopwatch()..start();
  final report = await preTranslateFile(
    repo: repo,
    glossary: glossary,
    client: client,
    model: a[1],
    fileId: 1,
    options: const PreTranslateOptions(maxUnits: 6),
    onProgress: (p) => print(
        'progress ${p.processed}/${p.total} saved=${p.saved} failed=${p.failed}'),
  );
  client.close();
  print(
      'done in ${sw.elapsedMilliseconds} ms: candidates=${report.candidates} saved=${report.saved} '
      'failed=${report.failed.length} warnings=${report.warnings} batches=${report.batches} '
      'prompt=${report.promptTokens} out=${report.completionTokens} clean=${report.clean} stopped=${report.stoppedBy}');
  for (final f in report.failed) print('  failed ${f.sourceId}: ${f.reasons}');
  for (final s in await repo.slots(1)) {
    final t = s.translation;
    print('  ${s.slotIdx}: ${t?.status} ${t?.text.replaceAll('\n', '\n')}');
  }
  await db.close();
}
