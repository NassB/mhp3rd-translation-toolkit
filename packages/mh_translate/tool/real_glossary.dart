// ignore_for_file: type=lint
// TA8 — contrôle réel de l'amorçage du glossaire. Usage :
//   dart run packages/mh_translate/tool/real_glossary.dart <projet> [endpoint model]
// N'affiche QUE des agrégats (aucun texte du jeu).
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final db = TdbDatabase.openFile(project.dbPath);
  final repo = TranslationRepository(db, locale: project.locale);
  final glossary = GlossaryRepository(db, locale: project.locale);
  final sw = Stopwatch()..start();
  final all = await projectTermCandidates(
    repo: repo,
    glossary: glossary,
    limit: 100000,
  );
  print(
      'scan: ${all.length} candidates (>=3 strings) in ${sw.elapsedMilliseconds} ms');
  for (final min in [3, 5, 10, 20]) {
    print('  count>=$min: ${all.where((c) => c.count >= min).length}');
  }
  final top = all.take(25).toList();
  print('top25 counts: ${top.map((c) => c.count).join(',')}');
  if (a.length >= 3) {
    final client = OpenAiCompatibleClient(
      endpoint: Uri.parse(a[1]),
      responseTimeout: const Duration(minutes: 5),
    );
    sw
      ..reset()
      ..start();
    final out = await proposeTermTranslations(
      client: client,
      model: a[2],
      candidates: top,
    );
    print(
        'proposals: ${out.length}/${top.length} in ${sw.elapsed.inSeconds} s');
    print(
        'lengths (chars): ${out.values.map((v) => v.runes.length).join(',')}');
    client.close();
  }
  await db.close();
}
