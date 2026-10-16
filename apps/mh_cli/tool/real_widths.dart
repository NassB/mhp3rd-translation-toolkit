// ignore_for_file: type=lint
// T38 — contrôle réel des métriques sur les traductions d'un projet.
//   dart run apps/mh_cli/tool/real_widths.dart <projet> [contexte=px7]
// N'affiche QUE des agrégats (aucun texte du jeu).
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final ctx = a.length > 1 ? a[1] : 'px7';
  final metrics = loadFontMetrics(defaultFontMetrics);
  final db = TdbDatabase.openFile(project.dbPath);
  final repo = TranslationRepository(db, locale: project.locale);
  final unk = <int, int>{};
  for (final f in await repo.listFiles()) {
    final widths = <int>[];
    var exact = 0, lines = 0, strings = 0, codes = 0, unknown = 0;
    for (final s
        in await repo.slots(f.id, limit: await repo.countSlots(f.id))) {
      final t = s.translation;
      if (s.isAlias || t == null || t.text.isEmpty) continue;
      strings++;
      for (final l in metrics.measure(t.text, ctx).lines) {
        lines++;
        widths.add(l.px);
        if (l.exact) exact++;
        if (l.codes.isNotEmpty) codes++;
        if (l.unknownGlyphs.isNotEmpty) unknown++;
        for (final c in l.unknownGlyphs) {
          unk[c] = (unk[c] ?? 0) + 1;
        }
      }
    }
    if (strings == 0) continue;
    widths.sort();
    int pct(int p) => widths[(widths.length - 1) * p ~/ 100];
    print('file ${f.id}: strings=$strings lines=$lines exact=$exact '
        'withCodes=$codes withUnknownGlyphs=$unknown '
        'px($ctx) p50=${pct(50)} p95=${pct(95)} max=${widths.last}');
  }
  final top = unk.entries.toList()..sort((x, y) => y.value - x.value);
  print('unknown glyphs (code point: count): '
      '${top.take(25).map((e) => 'U+${e.key.toRadixString(16).toUpperCase().padLeft(4, '0')}:${e.value}').join(' ')}');
  await db.close();
}
