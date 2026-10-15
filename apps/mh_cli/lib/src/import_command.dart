import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

const String _usage = 'usage: mhtk import --project <dir> --from <dump dir> '
    '--file <id> [--locale fr] [--status draft] '
    '[--config config/game_versions.yaml]';

/// `mhtk import` : applique un dossier de dump mhtools (`filelist.txt`,
/// `string_table_<j>.txt`, `enddata.bin`) au fichier d'ID `--file`.
///
/// Un dossier = un fichier : la disposition multi-fichiers des dumps mhtools
/// n'est pas documentée. L'original est relu dans l'ISO du projet (un seul
/// slot, voir `importDumpFolder`). Retourne le code de sortie.
Future<int> runImport(List<String> args, StringSink out, StringSink err) async {
  String? dir;
  String? from;
  int? fileId;
  String? locale;
  var status = 'draft';
  var config = defaultVersionsConfig;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project' when i + 1 < args.length:
        dir = args[++i];
      case '--from' when i + 1 < args.length:
        from = args[++i];
      case '--file' when i + 1 < args.length:
        fileId = int.tryParse(args[++i]);
      case '--locale' when i + 1 < args.length:
        locale = args[++i];
      case '--status' when i + 1 < args.length:
        status = args[++i];
      case '--config' when i + 1 < args.length:
        config = args[++i];
      default:
        err.writeln(_usage);
        return 64;
    }
  }
  if (dir == null || from == null || fileId == null) {
    err.writeln(_usage);
    return 64;
  }

  TdbDatabase? db;
  try {
    final loaded = Project.load(dir);
    final project = Project(
      dir: loaded.dir,
      isoPath: loaded.isoPath,
      versionId: loaded.versionId,
      locale: locale ?? loaded.locale,
    );
    db = TdbDatabase.openFile(project.dbPath);
    final n = await importDumpFolder(
      db: db,
      project: project,
      config: config,
      fileId: fileId,
      folder: from,
      status: status,
    );
    out.writeln('file $fileId: $n translations created or updated');
    return 0;
  } on MhError catch (e) {
    err.writeln('error: $e');
    return 1;
  } on FileSystemException catch (e) {
    err.writeln('error: ${e.message}: ${e.path}');
    return 1;
  } on FormatException catch (e) {
    err.writeln('error: invalid text file: ${e.message}');
    return 1;
  } finally {
    await db?.close();
  }
}
