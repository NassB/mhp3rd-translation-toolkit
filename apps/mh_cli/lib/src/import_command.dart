import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';

const String _usage = 'usage: mhtk import --project <dir> --from <dump dir> '
    '--file <id> [--locale fr] [--status draft] '
    '[--config config/game_versions.yaml]';

/// `mhtk import` : applique un dossier de dump mhtools (`filelist.txt`,
/// `string_table_<j>.txt`, `enddata.bin`) au fichier d'ID `--file`.
///
/// Un dossier = un fichier : la disposition multi-fichiers des dumps mhtools
/// n'est pas documentée. L'original est relu dans l'ISO du projet. Retourne
/// le code de sortie.
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

  IsoSession? session;
  TdbDatabase? db;
  try {
    final project = Project.load(dir);
    session = await IsoSession.open(project.isoPath, config);
    final entry = session.index.byId(fileId);
    final original = decodeStringTableA(
      session.readPlain(entry),
      fileId: fileId,
    );
    final dump = _readDump(from, original.tables.length);
    db = TdbDatabase.openFile(project.dbPath);
    final n = await importMhtoolsTranslations(
      db,
      fileId: fileId,
      original: original,
      dump: dump,
      locale: locale ?? project.locale,
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
    session?.close();
  }
}

/// Lit un dossier de dump mhtools pour un fichier de [tableCount] tables.
/// Une table sans `string_table_<j>.txt` est une table nulle.
MhtoolsDump _readDump(String from, int tableCount) {
  if (!Directory(from).existsSync()) {
    throw FileSystemException('dump folder not found', from);
  }
  String? read(String name) {
    final f = File('$from/$name');
    return f.existsSync() ? utf8.decode(f.readAsBytesSync()) : null;
  }

  final endData = File('$from/enddata.bin');
  return MhtoolsDump(
    fileListText: read('filelist.txt') ?? '',
    tableTexts: [
      for (var j = 0; j < tableCount; j++) read(mhtoolsTableFileName(j)),
    ],
    endData: endData.existsSync() ? endData.readAsBytesSync() : Uint8List(0),
  );
}
