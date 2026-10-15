// ignore_for_file: type=lint
// Contrôle local (T33) : export d'un dossier mhtools du projet réel dans out/.
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final db = TdbDatabase.openFile(project.dbPath);
  final sw = Stopwatch()..start();
  final tables = await exportDumpFolder(
    db: db,
    project: project,
    config: defaultVersionsConfig,
    fileId: int.parse(a[1]),
    folder: a[2],
  );
  print('exported $tables tables in ${sw.elapsedMilliseconds} ms');
  await db.close();
}
