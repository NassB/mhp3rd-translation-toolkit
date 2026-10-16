import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

const String _usage =
    'usage: mhtk calibrate --project <dir> --file <id>[,<id>...] '
    '[--force]';

/// `mhtk calibrate` : remplace les chaînes japonaises d'un fichier par des
/// chaînes de **test** (étiquette `[table.slot]` + motif de mesure) pour
/// calibrer l'affichage en jeu, puis écrit `<projet>/CALIBRATION.md`.
///
/// À utiliser sur un projet **séparé** (`mhtk init --locale calib …` puis
/// `mhtk extract`) : refuse un fichier qui contient déjà de vraies
/// traductions, sauf `--force`. Ne touche jamais à l'ISO ; l'ISO de
/// calibrage s'obtient ensuite avec `mhtk build --project <dir>`.
Future<int> runCalibrate(
  List<String> args,
  StringSink out,
  StringSink err,
) async {
  String? dir;
  List<int>? fileIds;
  var force = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--project' when i + 1 < args.length:
        dir = args[++i];
      case '--file' when i + 1 < args.length:
        fileIds = _ids(args[++i]);
      case '--force':
        force = true;
      default:
        err.writeln(_usage);
        return 64;
    }
  }
  if (dir == null || fileIds == null) {
    err.writeln(_usage);
    return 64;
  }

  TdbDatabase? db;
  try {
    final project = Project.load(dir);
    db = TdbDatabase.openFile(project.dbPath);
    for (final id in fileIds) {
      if (await gameFileById(db, id) == null) {
        throw TdbError('file not imported', fileId: id);
      }
    }
    final repo = TranslationRepository(db, locale: project.locale);
    final reports = <CalibrationReport>[];
    for (final id in fileIds) {
      final report = await applyCalibration(
        repo: repo,
        fileId: id,
        force: force,
      );
      reports.add(report);
      out.writeln(
        'file $id: ${report.rows.length} string(s) replaced by calibration '
        'text, ${report.untouched} left as they are (byte delta '
        '${report.deltaBytes}, never above 0)',
      );
    }
    final md = '$dir/CALIBRATION.md';
    File(md).writeAsStringSync(reports.map(calibrationMarkdown).join('\n'));
    out
      ..writeln('project:  $dir (${project.locale})')
      ..writeln('report:   $md')
      ..writeln('next:     mhtk build --project $dir '
          '--out out/MHP3.${project.locale}.iso');
    if (project.locale != 'calib') {
      out.writeln('note:     the project locale is "${project.locale}", not '
          '"calib": keep this project for calibration only.');
    }
    return 0;
  } on MhError catch (e) {
    err.writeln('error: $e');
    return 1;
  } on FileSystemException catch (e) {
    err.writeln('error: ${e.message}: ${e.path}');
    return 1;
  } finally {
    await db?.close();
  }
}

/// « 17,2813 » -> [17, 2813] ; `null` si un élément n'est pas un entier ou
/// si la liste est vide.
List<int>? _ids(String text) {
  final ids = [for (final p in text.split(',')) int.tryParse(p.trim())];
  return ids.isEmpty || ids.contains(null) ? null : ids.cast<int>();
}
