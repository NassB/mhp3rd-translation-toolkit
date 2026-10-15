// ignore_for_file: type=lint
// Contrôle local (guide T35) : taille et nombre de chaînes de chaque fichier
// du projet. N'affiche aucun texte du jeu.
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final db = TdbDatabase.openFile(project.dbPath);
  final repo = TranslationRepository(db, locale: project.locale);
  for (final f in await repo.listFiles()) {
    final slots = await repo.countSlots(f.id);
    print('file ${f.id}: ${f.origBytes} bytes, ${f.totalStrings} strings '
        '(${slots} slots)');
  }
  await db.close();
}
