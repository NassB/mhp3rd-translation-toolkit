import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

const String _usage = '''
usage: mhtk profile list [--profiles config/profiles.yaml]
       mhtk profile show --project <dir> [--file <id>]
       mhtk profile set --project <dir> --file <id> [--table <n>] --profile <id>
       mhtk profile set --project <dir> --file <id> [--table <n>] --clear

Length profiles (docs/ARCHITECTURE.md §8.4) are defined in
config/profiles.yaml; the project only stores which profile applies to a file
(default), or to one table of a file. 0 in the YAML means "not measured".''';

/// `mhtk profile` : liste les profils de longueur, montre leur répartition
/// dans un projet, ou les assigne à un fichier ou une table. Retourne le code
/// de sortie (0 ; 1 erreur ; 64 usage).
Future<int> runProfile(
  List<String> args,
  StringSink out,
  StringSink err,
) async {
  if (args.isEmpty) {
    err.writeln(_usage);
    return 64;
  }
  final sub = args.first;
  String? profilesPath;
  String? dir;
  int? fileId;
  int? tableIdx;
  String? profile;
  var clear = false;
  final rest = args.sublist(1);
  for (var i = 0; i < rest.length; i++) {
    switch (rest[i]) {
      case '--profiles' when i + 1 < rest.length:
        profilesPath = rest[++i];
      case '--project' when i + 1 < rest.length:
        dir = rest[++i];
      case '--file' when i + 1 < rest.length:
        fileId = int.tryParse(rest[++i]);
        if (fileId == null) {
          err.writeln(_usage);
          return 64;
        }
      case '--table' when i + 1 < rest.length:
        tableIdx = int.tryParse(rest[++i]);
        if (tableIdx == null) {
          err.writeln(_usage);
          return 64;
        }
      case '--profile' when i + 1 < rest.length:
        profile = rest[++i];
      case '--clear':
        clear = true;
      default:
        err.writeln(_usage);
        return 64;
    }
  }

  TdbDatabase? db;
  try {
    switch (sub) {
      case 'list' when dir == null:
        final profiles = loadLengthProfiles(profilesPath ?? defaultProfiles);
        for (final p in profiles.all) {
          out.writeln(
            '${p.id}: max_px ${p.maxPx == 0 ? 'unmeasured' : p.maxPx}, '
            'max_lines ${p.maxLines == 0 ? 'unmeasured' : p.maxLines}, '
            'font ${p.fontContext ?? 'unmeasured'}'
            '${p.paginated ? ', paginated' : ''}'
            '${p.hasLimits ? '' : ' (no limit: no warning)'}',
          );
        }
        return 0;
      case 'show' when dir != null:
        final project = Project.load(dir);
        db = TdbDatabase.openFile(project.dbPath);
        final repo = ProfileRepository(db);
        final all = await TranslationRepository(
          db,
          locale: project.locale,
        ).listFiles();
        final files = fileId != null ? [fileId] : [for (final f in all) f.id];
        for (final id in files) {
          final counts = await repo.countByProfile(id);
          final text = [
            for (final e in counts.entries) '${e.key ?? '(none)'}: ${e.value}',
          ].join(', ');
          out.writeln('file $id: $text');
        }
        return 0;
      case 'set' when dir != null && fileId != null:
        if ((profile == null) == !clear) {
          err.writeln('error: give exactly one of --profile <id> or --clear');
          return 64;
        }
        final project = Project.load(dir);
        db = TdbDatabase.openFile(project.dbPath);
        final repo = ProfileRepository(db);
        final id = clear ? null : profile;
        final profiles = loadLengthProfiles(profilesPath ?? defaultProfiles);
        if (tableIdx == null) {
          await repo.setFileProfile(fileId, id, knownIds: profiles.ids);
          out.writeln('file $fileId: default profile '
              '${id == null ? 'cleared' : 'set to $id'}');
        } else {
          final n = await repo.setTableProfile(
            fileId,
            tableIdx,
            id,
            knownIds: profiles.ids,
          );
          out.writeln('file $fileId table $tableIdx: $n string(s) '
              '${id == null ? 'cleared' : 'set to $id'}');
        }
        return 0;
      default:
        err.writeln(_usage);
        return 64;
    }
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
