import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

const String _usage = 'usage: mhtk init --iso <game.iso> --project <dir> '
    '[--locale fr] [--config config/game_versions.yaml]';

/// `mhtk init` : vérifie l'ISO (MD5, offset de DATA.BIN) puis crée le projet
/// (`project.json` + `tdb.sqlite`). Retourne le code de sortie.
Future<int> runInit(List<String> args, StringSink out, StringSink err) async {
  String? iso;
  String? dir;
  var locale = 'fr';
  var config = defaultVersionsConfig;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--iso' when i + 1 < args.length:
        iso = args[++i];
      case '--project' when i + 1 < args.length:
        dir = args[++i];
      case '--locale' when i + 1 < args.length:
        locale = args[++i];
      case '--config' when i + 1 < args.length:
        config = args[++i];
      default:
        err.writeln(_usage);
        return 64;
    }
  }
  if (iso == null || dir == null) {
    err.writeln(_usage);
    return 64;
  }

  try {
    if (File('$dir/$projectFileName').existsSync() ||
        File('$dir/$projectDbName').existsSync()) {
      throw IsoError('project already exists: $dir');
    }
    final session = await IsoSession.open(iso, config);
    final versionId = session.image.version.id;
    final fileCount = session.index.entries.length;
    session.close();

    Directory(dir).createSync(recursive: true);
    final project = Project(
      dir: dir,
      isoPath: File(iso).absolute.path,
      versionId: versionId,
      locale: locale,
    );
    project.save();
    final db = TdbDatabase.openFile(project.dbPath);
    try {
      await db.customSelect('SELECT 1').get(); // force la création du schéma
    } finally {
      await db.close();
    }
    out
      ..writeln('project:  $dir')
      ..writeln('version:  $versionId')
      ..writeln('files:    $fileCount in DATA.BIN')
      ..writeln('locale:   $locale');
    return 0;
  } on MhError catch (e) {
    err.writeln('error: $e');
    return 1;
  } on FileSystemException catch (e) {
    err.writeln('error: ${e.message}: ${e.path}');
    return 1;
  }
}
