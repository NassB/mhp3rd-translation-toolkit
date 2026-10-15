import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'project.dart';

const String _usage =
    'usage: mhtk extract --project <dir> [--config config/game_versions.yaml]';

/// `mhtk extract` : détecte les `string_table_a` de `DATA.BIN` et les importe
/// dans la base du projet. Relançable : les fichiers déjà importés sont
/// ignorés. Retourne le code de sortie.
///
/// Critère de détection (docs/PROGRESS.md, faux positifs de T13) : décodage
/// strict réussi, au moins une table non nulle et un slot non vide.
Future<int> runExtract(
  List<String> args,
  StringSink out,
  StringSink err,
) async {
  String? dir;
  var config = defaultVersionsConfig;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project' when i + 1 < args.length:
        dir = args[++i];
      case '--config' when i + 1 < args.length:
        config = args[++i];
      default:
        err.writeln(_usage);
        return 64;
    }
  }
  if (dir == null) {
    err.writeln(_usage);
    return 64;
  }

  IsoSession? session;
  TdbDatabase? db;
  try {
    final project = Project.load(dir);
    session = await IsoSession.open(project.isoPath, config);
    db = TdbDatabase.openFile(project.dbPath);
    final known = await importedFileIds(db);
    var detected = 0;
    var imported = 0;
    for (final e in session.index.entries) {
      if (e.slotBytes == 0) continue;
      final plain = session.readPlain(e);
      final StringTableFile file;
      try {
        file = decodeStringTableA(plain, fileId: e.id);
      } on FormatError {
        continue;
      }
      final hasText = file.tables.any(
        (t) => t != null && t.slots.any((s) => s.raw.isNotEmpty),
      );
      if (!hasText) continue;
      detected++;
      if (known.contains(e.id)) continue;
      await importSourceFile(
        db,
        fileId: e.id,
        versionId: project.versionId,
        lba: e.lba,
        slotBytes: e.slotBytes,
        origBytes: plain.length,
        file: file,
      );
      imported++;
    }
    out
      ..writeln('detected: $detected string_table_a')
      ..writeln('imported: $imported')
      ..writeln('already:  ${detected - imported}');
    return 0;
  } on MhError catch (e) {
    err.writeln('error: $e');
    return 1;
  } on FileSystemException catch (e) {
    err.writeln('error: ${e.message}: ${e.path}');
    return 1;
  } finally {
    await db?.close();
    session?.close();
  }
}
