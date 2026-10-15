// ignore_for_file: type=lint
// Contrôle local (TA4b) : ancienne règle (plafond = octets de la source) contre
// l'enveloppe du fichier, sur les 50 premières chaînes de #2819. Compteurs
// seulement, aucun texte du jeu.
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

Future<void> run(String dir, String label, PreTranslateOptions o, String model,
    Uri ep) async {
  final project = Project.load(dir);
  final db = TdbDatabase.openFile(project.dbPath);
  final client = OpenAiCompatibleClient(endpoint: ep);
  final sw = Stopwatch()..start();
  final r = await preTranslateFile(
      repo: TranslationRepository(db, locale: project.locale),
      glossary: GlossaryRepository(db, locale: project.locale),
      client: client,
      model: model,
      fileId: 2819,
      options: o);
  final reasons = <FailureReason, int>{};
  for (final f in r.failed)
    for (final x in f.reasons) reasons[x] = (reasons[x] ?? 0) + 1;
  print(
      '$label: ${sw.elapsed.inSeconds}s candidates=${r.candidates} saved=${r.saved} failed=${r.failed.length} '
      '$reasons shortened=${r.shortened} start=${r.startDeltaBytes} end=${r.endDeltaBytes} '
      'within=${r.withinBudget} requests=${r.batches} prompt=${r.promptTokens} out=${r.completionTokens}');
  client.close();
  await db.close();
}

Future<void> main(List<String> a) async {
  final ep = Uri.parse(a[0]);
  await run(
      'out/ta4b_old',
      'OLD (cap=source, no envelope)',
      const PreTranslateOptions(
          limit: 50,
          perStringFactor: 1.0,
          minMaxBytes: 12,
          enforceFileBudget: false),
      a[1],
      ep);
  await run('out/ta4b_new', 'NEW (envelope)',
      const PreTranslateOptions(limit: 50), a[1], ep);
}
