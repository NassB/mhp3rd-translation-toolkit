// ignore_for_file: type=lint
// TA7 — évaluation comparée de deux modèles sur un échantillon réel
// (docs/QA_PRETRADUCTION.md). Chaque modèle traduit les mêmes N chaînes de
// #2819 ; chaque production est ensuite notée et rétro-traduite par l'AUTRE
// modèle (indépendance). Usage :
//   dart run packages/mh_translate/tool/eval_models.dart <endpoint> \
//       <modelA> <modelB> <projectA> <projectB> <fileId> <N> <reportPath>
//
// Affiche UNIQUEMENT des agrégats (aucun texte du jeu). Le rapport détaillé
// (texte du jeu et traductions) est écrit dans <reportPath>, sous out/ (ignoré
// par git) : à lire à la main, jamais à commiter.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

class Row {
  Row(this.id, this.source, this.text);
  final int id;
  final String source;
  final String text;
  JudgeScore? score; // note de l'autre modèle
  String? back; // rétro-traduction par l'autre modèle
  double? sim;
}

class Run {
  Run(this.model);
  final String model;
  late PreTranslateReport report;
  late Duration elapsed;
  final rows = <Row>[];
}

Future<Run> translate(
    Uri ep, String model, String dir, int fileId, int n) async {
  final project = Project.load(dir);
  final db = TdbDatabase.openFile(project.dbPath);
  final repo = TranslationRepository(db, locale: project.locale);
  final client = OpenAiCompatibleClient(
    endpoint: ep,
    responseTimeout: const Duration(minutes: 10),
  );
  final run = Run(model);
  final sw = Stopwatch()..start();
  run.report = await preTranslateFile(
    repo: repo,
    glossary: GlossaryRepository(db, locale: project.locale),
    client: client,
    model: model,
    fileId: fileId,
    options: PreTranslateOptions(limit: n),
  );
  run.elapsed = sw.elapsed;
  for (final s
      in await repo.slots(fileId, limit: await repo.countSlots(fileId))) {
    final t = s.translation;
    if (t != null && (t.authorId ?? '').startsWith('ai:')) {
      run.rows.add(Row(s.sourceId, s.sourceText, t.text));
    }
  }
  client.close();
  await db.close();
  return run;
}

/// Note et rétro-traduit [rows] avec [model] (un autre modèle que l'auteur).
Future<void> assess(Uri ep, String model, List<Row> rows) async {
  final client = OpenAiCompatibleClient(
    endpoint: ep,
    responseTimeout: const Duration(minutes: 10),
  );
  const chunk = 20;
  for (var i = 0; i < rows.length; i += chunk) {
    final part = rows.sublist(i, math.min(i + chunk, rows.length));
    try {
      final r = await client.chat(
        model: model,
        messages: buildJudgeMessages([
          for (final x in part)
            JudgeItem(id: x.id, source: x.source, translation: x.text),
        ]),
        temperature: 0.0,
        maxTokens: 4000,
        jsonSchema: judgeSchema(),
      );
      final scores = parseJudgeScores(r.content, part.map((x) => x.id));
      for (final x in part) x.score = scores[x.id];
    } on TranslateError catch (e) {
      stderr.writeln('judge batch failed: ${e.kind.name}');
    }
    try {
      final units = [
        for (final x in part)
          TranslationUnit(id: x.id, source: x.text, maxBytes: 600),
      ];
      final batch = Batch(units, 0);
      final r = await client.chat(
        model: model,
        messages: buildBackTranslationMessages(batch),
        temperature: 0.0,
        maxTokens: 4000,
        jsonSchema: translationSchema(),
      );
      final back = parseTranslations(r.content, batch).translations;
      for (final x in part) {
        x.back = back[x.id];
        if (x.back != null) x.sim = roundTripSimilarity(x.source, x.back!);
      }
    } on TranslateError catch (e) {
      stderr.writeln('back-translation batch failed: ${e.kind.name}');
    }
  }
  client.close();
}

int bytes(String s) => s.codeUnits.length; // approximation sans importance ici

String pct(num a, num b) =>
    b == 0 ? 'n/a' : '${(100 * a / b).toStringAsFixed(0)}%';

double mean(Iterable<double> v) =>
    v.isEmpty ? double.nan : v.reduce((a, b) => a + b) / v.length;

double median(List<double> v) {
  if (v.isEmpty) return double.nan;
  final s = [...v]..sort();
  return s.length.isOdd
      ? s[s.length ~/ 2]
      : (s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2;
}

void summary(String label, Run r) {
  final rep = r.report;
  final scored = r.rows.where((x) => x.score != null).toList();
  final sims = [
    for (final x in r.rows)
      if (x.sim != null) x.sim!
  ];
  final issues = <String, int>{};
  for (final x in scored) {
    for (final i in x.score!.issues) issues[i] = (issues[i] ?? 0) + 1;
  }
  final reasons = <FailureReason, int>{};
  for (final f in rep.failed)
    for (final x in f.reasons) reasons[x] = (reasons[x] ?? 0) + 1;
  final ratio = [
    for (final x in r.rows) utf8Len(x.text) / math.max(1, utf8Len(x.source)),
  ];
  print('--- $label (${r.model})');
  print(
      '  translation: candidates=${rep.candidates} saved=${rep.saved} failed=${rep.failed.length} $reasons '
      'shortened=${rep.shortened} warnings=${rep.warnings} withinBudget=${rep.withinBudget} endDelta=${rep.endDeltaBytes}');
  print(
      '  speed: ${r.elapsed.inSeconds}s total, ${(r.elapsed.inMilliseconds / math.max(1, rep.candidates) / 1000).toStringAsFixed(2)}s/string, '
      'requests=${rep.batches}, tokens prompt=${rep.promptTokens} completion=${rep.completionTokens}');
  print(
      '  size: translation/source bytes ratio mean=${mean(ratio).toStringAsFixed(2)} median=${median(ratio).toStringAsFixed(2)}');
  print(
      '  judge (by the other model): judged=${scored.length}/${r.rows.length} '
      'mean=${mean(scored.map((x) => x.score!.score.toDouble())).toStringAsFixed(2)} '
      '>=4: ${pct(scored.where((x) => x.score!.score >= 4).length, scored.length)} '
      '<=2: ${pct(scored.where((x) => x.score!.score <= 2).length, scored.length)} issues=$issues');
  print(
      '  round-trip similarity (JA vs back-translation): n=${sims.length} mean=${mean(sims).toStringAsFixed(2)} '
      'median=${median(sims).toStringAsFixed(2)} <0.15: ${pct(sims.where((s) => s < 0.15).length, sims.length)}');
}

int utf8Len(String s) => const Utf8Encoder().convert(s).length;

Future<void> main(List<String> a) async {
  final ep = Uri.parse(a[0]);
  final modelA = a[1], modelB = a[2];
  final fileId = int.parse(a[5]);
  final n = int.parse(a[6]);
  final reportPath = a[7];

  stdout.writeln('1/4 translating with A…');
  final ra = await translate(ep, modelA, a[3], fileId, n);
  stdout.writeln('2/4 translating with B…');
  final rb = await translate(ep, modelB, a[4], fileId, n);
  stdout.writeln('3/4 B assesses A…');
  await assess(ep, modelB, ra.rows);
  stdout.writeln('4/4 A assesses B…');
  await assess(ep, modelA, rb.rows);

  summary('A', ra);
  summary('B', rb);

  final buf = StringBuffer()
    ..writeln(
        '# TA7 — rapport détaillé (CONTIENT DU TEXTE DU JEU : ne pas commiter)')
    ..writeln()
    ..writeln(
        'A = $modelA ; B = $modelB ; fichier $fileId ; ${ra.rows.length}/${rb.rows.length} chaînes.')
    ..writeln(
        'Chaque traduction est notée (1-5) et rétro-traduite par l\'autre modèle.')
    ..writeln();
  final bById = {for (final x in rb.rows) x.id: x};
  for (final x in ra.rows) {
    final y = bById[x.id];
    buf
      ..writeln('## #${x.id}')
      ..writeln('- JA : ${x.source.replaceAll('\n', ' ⏎ ')}')
      ..writeln(
          '- A : ${x.text.replaceAll('\n', ' ⏎ ')}  → note ${x.score?.score ?? '?'} ${x.score?.issues ?? ''} ; rétro : ${x.back?.replaceAll('\n', ' ⏎ ') ?? '?'} (sim ${x.sim?.toStringAsFixed(2) ?? '?'})');
    if (y != null) {
      buf.writeln(
          '- B : ${y.text.replaceAll('\n', ' ⏎ ')}  → note ${y.score?.score ?? '?'} ${y.score?.issues ?? ''} ; rétro : ${y.back?.replaceAll('\n', ' ⏎ ') ?? '?'} (sim ${y.sim?.toStringAsFixed(2) ?? '?'})');
    }
    buf.writeln();
  }
  File(reportPath).createSync(recursive: true);
  File(reportPath).writeAsStringSync(buf.toString());
  print('detailed report (game text, local only): $reportPath');
}
