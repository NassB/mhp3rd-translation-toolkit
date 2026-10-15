// ignore_for_file: type=lint
// Contrôle local : coût de l'index de mémoire de traduction sur les vraies
// chaînes du projet (T32). N'affiche aucun texte du jeu.
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final db = TdbDatabase.openFile(project.dbPath);
  final repo = TranslationRepository(db, locale: project.locale);
  final pairs = <({int id, String source, String target})>[];
  for (final f in await repo.listFiles()) {
    for (final s
        in await repo.slots(f.id, limit: await repo.countSlots(f.id))) {
      if (!s.isAlias) {
        pairs.add((id: s.sourceId, source: s.sourceText, target: s.sourceText));
      }
    }
  }
  final sw = Stopwatch()..start();
  final tm = TranslationMemory.fromPairs(pairs);
  print('index: ${tm.length} entries in ${sw.elapsedMilliseconds} ms');
  sw
    ..reset()
    ..start();
  var found = 0;
  final step = pairs.length ~/ 200;
  for (var i = 0; i < pairs.length; i += step) {
    found += tm.suggest(pairs[i].source, excludeSourceId: pairs[i].id).length;
  }
  print('200 queries: ${sw.elapsedMilliseconds} ms, $found matches');
  await db.close();
}
