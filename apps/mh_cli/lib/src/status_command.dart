import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'project.dart';

const String _usage = 'usage: mhtk status --project <dir>';

/// `mhtk status` : contenu de la base du projet. Retourne le code de sortie.
Future<int> runStatus(List<String> args, StringSink out, StringSink err) async {
  if (args.length != 2 || args[0] != '--project') {
    err.writeln(_usage);
    return 64;
  }
  TdbDatabase? db;
  try {
    final project = Project.load(args[1]);
    if (!File(project.dbPath).existsSync()) {
      throw IsoError('missing ${project.dbPath}');
    }
    db = TdbDatabase.openFile(project.dbPath);
    final s = await tdbStatus(db, locale: project.locale);
    out
      ..writeln('version:  ${project.versionId}')
      ..writeln('locale:   ${project.locale}')
      ..writeln('files:    ${s.files}')
      ..writeln('strings:  ${s.strings}');
    for (final e in s.translationsByStatus.entries) {
      out.writeln('  ${e.key.padRight(13)} ${e.value}');
    }
    return 0;
  } on MhError catch (e) {
    err.writeln('error: $e');
    return 1;
  } finally {
    await db?.close();
  }
}
