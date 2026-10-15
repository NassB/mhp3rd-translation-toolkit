import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'budget_build_support.dart';

const String _usage = 'usage: mhtk budget --project <dir> --file <id> '
    '[--policy strict|slot] [--min-status draft] [--config ...] '
    '[--validated config/validated_files.yaml]';

/// `mhtk budget` : budget (niveaux 1 et 2) d'un fichier avec les traductions
/// éligibles. Sans traduction éligible, rapport de la situation d'origine.
/// Retourne 0 si le budget est respecté, 1 sinon.
Future<int> runBudget(List<String> args, StringSink out, StringSink err) async {
  final f = parseFlags(args, {
    'project',
    'file',
    'policy',
    'min-status',
    'config',
    'validated',
  });
  final fileId = int.tryParse(f?['file'] ?? '');
  final policy = parsePolicy(f?['policy'] ?? 'strict');
  if (f == null || f['project'] == null || fileId == null || policy == null) {
    err.writeln(_usage);
    return 64;
  }

  IsoSession? session;
  TdbDatabase? db;
  try {
    final project = Project.load(f['project']!);
    session = await IsoSession.open(
      project.isoPath,
      f['config'] ?? defaultVersionsConfig,
    );
    final entry = session.index.byId(fileId);
    db = TdbDatabase.openFile(project.dbPath);
    final allowed = loadValidatedFiles(f['validated'] ?? defaultValidatedFiles);
    final result = await buildPatch(
      db: db,
      index: session.index,
      readPlain: session.readPlain,
      locale: project.locale,
      minStatus: f['min-status'] ?? 'draft',
      policy: policy,
      slotAllowedFileIds: allowed,
      onlyFileIds: {fileId},
    );
    final withTranslations = result.reports.isNotEmpty;
    final report = withTranslations
        ? result.reports.single
        : evaluateFileBudget(
            fileId: fileId,
            origBytes: session.readPlain(entry).length,
            rebuiltBytes: session.readPlain(entry).length,
            slotBytes: entry.slotBytes,
            policy: policy,
            slotAllowedFileIds: allowed,
          );
    final limit =
        policy == BudgetPolicy.strict ? report.origBytes : report.slotBytes;
    out
      ..writeln('file $fileId'
          '${withTranslations ? '' : ' (no eligible translation)'}')
      ..writeln('  orig:     ${report.origBytes} bytes')
      ..writeln('  slot:     ${report.slotBytes} bytes')
      ..writeln(
        '  rebuilt:  ${report.rebuiltBytes} bytes '
        '(aligned ${report.alignedBytes})',
      )
      ..writeln(
        '  margin:   ${limit - report.rebuiltBytes} bytes '
        '(policy ${policy.name})',
      )
      ..writeln('  status:   ${report.status.name}');
    return report.isOk ? 0 : 1;
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
