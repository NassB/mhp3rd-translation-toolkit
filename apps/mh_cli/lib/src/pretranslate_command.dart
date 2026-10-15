import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

const String _usage = '''
usage: mhtk pretranslate --project <dir> --file <id> --model <id>
         [--endpoint http://localhost:1234/v1] [--limit N] [--include-drafts] [--ai-drafts-only]
         [--dry-run] [--allow-remote] [--log <file.jsonl>] [--log-text]
       mhtk pretranslate --list-models [--endpoint ...]

Translates untranslated Japanese strings with a language model and saves them
as drafts (never over translated/reviewed/locked ones). Game text is sent only
to the endpoint, which must be local unless --allow-remote is given. No game
text is ever printed. Environment: MHTK_LLM_ENDPOINT (default endpoint),
MHTK_LLM_API_KEY (optional bearer key).

A JSON Lines log is written to <project>/logs/pretranslate-<file>-<time>.jsonl
(or --log): ids, reasons and sizes only. --log-text also writes the Japanese
source and the rejected proposals: keep that file local.''';

/// Crée le client de chat ; remplaçable dans les tests.
typedef ChatClientFactory = ChatClient Function(Uri endpoint, String? apiKey);

ChatClient _defaultFactory(Uri endpoint, String? apiKey) =>
    OpenAiCompatibleClient(endpoint: endpoint, apiKey: apiKey);

/// `mhtk pretranslate` : voir `_usage`. Retourne le code de sortie (0 : tout
/// s'est déroulé, même si certaines chaînes sont en échec ; 1 : erreur, arrêt
/// du fournisseur ou annulation ; 64 : usage).
Future<int> runPretranslate(
  List<String> args,
  StringSink out,
  StringSink err, {
  ChatClientFactory clientFactory = _defaultFactory,
  Map<String, String>? env,
  CancelToken? cancel,
}) async {
  final environment = env ?? Platform.environment;
  final values = <String, String>{};
  final flags = <String>{};
  const withValue = {'project', 'file', 'model', 'endpoint', 'limit', 'log'};
  const bare = {
    'include-drafts',
    'ai-drafts-only',
    'dry-run',
    'allow-remote',
    'list-models',
    'log-text',
  };
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) {
      err.writeln(_usage);
      return 64;
    }
    final name = a.substring(2);
    if (bare.contains(name)) {
      flags.add(name);
    } else if (withValue.contains(name) && i + 1 < args.length) {
      values[name] = args[++i];
    } else {
      err.writeln(_usage);
      return 64;
    }
  }

  final endpointText = values['endpoint'] ??
      environment['MHTK_LLM_ENDPOINT'] ??
      'http://localhost:1234/v1';
  final endpoint = Uri.tryParse(endpointText);
  if (endpoint == null || !endpoint.hasScheme || endpoint.host.isEmpty) {
    err.writeln('error: invalid endpoint');
    return 64;
  }
  final apiKey = environment['MHTK_LLM_API_KEY'];
  final local = isLocalEndpoint(endpoint);

  Future<int> listModels() async {
    final client = clientFactory(endpoint, apiKey);
    try {
      for (final id in await client.listModels()) {
        out.writeln(id);
      }
      return 0;
    } on TranslateError catch (e) {
      err.writeln('error: $e');
      return 1;
    } finally {
      if (client is OpenAiCompatibleClient) client.close();
    }
  }

  if (flags.contains('list-models')) return listModels();

  final dir = values['project'];
  final fileId = int.tryParse(values['file'] ?? '');
  final limit =
      values.containsKey('limit') ? int.tryParse(values['limit']!) : null;
  final dryRun = flags.contains('dry-run');
  final model = values['model'];
  if (dir == null ||
      fileId == null ||
      (model == null && !dryRun) ||
      (values.containsKey('limit') && (limit == null || limit < 1))) {
    err.writeln(_usage);
    return 64;
  }
  if (!dryRun && !local && !flags.contains('allow-remote')) {
    err.writeln(
      'error: ${endpoint.host} is not a local endpoint: the game text would be '
      'sent to a third party. Use a local server, or pass --allow-remote if '
      'you accept that.',
    );
    return 64;
  }

  TdbDatabase? db;
  ChatClient? client;
  try {
    final project = Project.load(dir);
    db = TdbDatabase.openFile(project.dbPath);
    final repo = TranslationRepository(db, locale: project.locale);
    final glossary = GlossaryRepository(db, locale: project.locale);
    if (await gameFileById(db, fileId) == null) {
      throw TdbError('file not imported', fileId: fileId);
    }
    final options = PreTranslateOptions(
      includeDrafts:
          flags.contains('include-drafts') || flags.contains('ai-drafts-only'),
      aiDraftsOnly: flags.contains('ai-drafts-only'),
      limit: limit,
      prompt: PromptOptions(
        targetLanguage: languageNameOf(project.locale),
      ),
    );

    final plan = await planPreTranslation(
      repo: repo,
      fileId: fileId,
      options: options,
    );
    out
      ..writeln('project:  $dir (${project.locale})')
      ..writeln('endpoint: ${endpoint.origin}${endpoint.path} '
          '(${local ? 'local' : 'REMOTE'})')
      ..writeln('file $fileId: ${plan.candidates} string(s) to translate in '
          '${plan.batches} batch(es), ~${plan.estimatedPromptTokens} prompt '
          'tokens; skipped: ${plan.skippedEmpty} empty, '
          '${plan.skippedNoJapanese} without Japanese')
      ..writeln('file byte budget: ${plan.budgetMarginBytes} byte(s) of '
          'margin before this run');
    if (dryRun) {
      out.writeln('dry run: nothing was sent, nothing was written');
      return 0;
    }
    if (!local) {
      out.writeln(
        'WARNING: the game text is being sent to ${endpoint.host} '
        '(--allow-remote).',
      );
    }
    if (plan.candidates == 0) {
      out.writeln('nothing to translate');
      return 0;
    }

    final logPath = values['log'] ?? defaultLogPath(dir, fileId);
    final log = JsonlFileLog(logPath, includeText: flags.contains('log-text'));
    client = clientFactory(endpoint, apiKey);
    final started = DateTime.now();
    final report = await preTranslateFile(
      repo: repo,
      glossary: glossary,
      client: client,
      model: model!,
      fileId: fileId,
      options: options,
      cancel: cancel,
      log: log,
      onProgress: (p) => out.writeln(
        'progress ${p.processed}/${p.total}: saved ${p.saved}, '
        'failed ${p.failed}',
      ),
    );
    final byReason = <FailureReason, int>{};
    for (final f in report.failed) {
      for (final r in f.reasons) {
        byReason[r] = (byReason[r] ?? 0) + 1;
      }
    }
    final reasons = byReason.isEmpty
        ? ''
        : ' (${byReason.entries.map((e) => '${e.key.name}: ${e.value}').join(', ')})';
    out
      ..writeln('saved ${report.saved} draft(s); failed '
          '${report.failed.length}$reasons; conflicts ${report.conflicts}; '
          'warnings ${report.warnings}')
      ..writeln('tokens: prompt ${report.promptTokens}, completion '
          '${report.completionTokens}; ${report.batches} request(s) in '
          '${DateTime.now().difference(started).inSeconds}s')
      ..writeln(
        report.withinBudget
            ? 'file byte budget: within the original (margin '
                '${-report.endDeltaBytes} byte(s), ${report.shortened} '
                'string(s) shortened)'
            : 'WARNING: the file exceeds its original size by '
                '${report.overBudgetBytes} byte(s): shorten some drafts in '
                'the studio before promoting them',
      );
    out.writeln(
      'log: $logPath'
      '${flags.contains('log-text') ? ' (contains game text: keep it local)' : ''}',
    );
    if (report.cancelled) {
      out.writeln('cancelled: ${report.unprocessed} string(s) not processed');
      return 1;
    }
    final stop = report.stoppedBy;
    if (stop != null) {
      err.writeln('stopped: $stop (${report.unprocessed} not processed)');
      return 1;
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
    if (client is OpenAiCompatibleClient) client.close();
  }
}
