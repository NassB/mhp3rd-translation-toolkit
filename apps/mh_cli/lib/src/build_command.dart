import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'budget_build_support.dart';
import 'project.dart';

const String _usage = 'usage: mhtk build --project <dir> --target iso '
    '[--out out/MHP3.<locale>.iso] [--policy strict|slot] '
    '[--min-status translated] [--profile nightly] [--config ...] '
    '[--validated config/validated_files.yaml]';

/// `mhtk build` : écrit les traductions éligibles dans une copie de l'ISO
/// (l'ISO source n'est jamais modifiée). Retourne 0 si le build est `ok` ou
/// s'il n'y a rien à construire, 1 sinon.
Future<int> runBuildCommand(
  List<String> args,
  StringSink out,
  StringSink err,
) async {
  final f = parseFlags(args, {
    'project',
    'target',
    'out',
    'policy',
    'min-status',
    'profile',
    'config',
    'validated',
  });
  final policy = parsePolicy(f?['policy'] ?? 'strict');
  if (f == null || f['project'] == null || policy == null) {
    err.writeln(_usage);
    return 64;
  }
  if ((f['target'] ?? 'iso') != 'iso') {
    err.writeln('error: target "${f['target']}" is not supported yet (iso)');
    return 64;
  }

  IsoSession? session;
  TdbDatabase? db;
  try {
    final project = Project.load(f['project']!);
    final outPath = f['out'] ?? 'out/MHP3.${project.locale}.iso';
    session = await IsoSession.open(
      project.isoPath,
      f['config'] ?? defaultVersionsConfig,
    );
    db = TdbDatabase.openFile(project.dbPath);
    final parent = File(outPath).absolute.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    final run = await runBuild(
      db: db,
      iso: session.image,
      index: session.index,
      readPlain: session.readPlain,
      locale: project.locale,
      outPath: outPath,
      toolkitVersion: toolkitVersion,
      profile: f['profile'] ?? 'nightly',
      minStatus: f['min-status'] ?? 'translated',
      policy: policy,
      slotAllowedFileIds: loadValidatedFiles(
        f['validated'] ?? defaultValidatedFiles,
      ),
    );
    out
      ..writeln('status:   ${run.status}')
      ..writeln('build:    ${run.buildId} (tdb revision ${run.tdbRevision})');
    for (final r in run.result.reports) {
      out.writeln(
        '  file ${r.fileId}: ${r.status.name} '
        '(${r.rebuiltBytes}/${r.origBytes} bytes, slot ${r.slotBytes})',
      );
    }
    for (final e in run.verifyErrors) {
      err.writeln('verify: $e');
    }
    if (run.ok) out.writeln('output:   $outPath');
    return run.ok || run.status == BuildStatus.nothingToBuild ? 0 : 1;
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
