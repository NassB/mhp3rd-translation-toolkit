// ignore_for_file: type=lint
// Contrôle réel des codes `~Xnn` dans les sources et les brouillons IA.
//   dart run packages/mh_translate/tool/real_codes.dart <projet>
// N'affiche QUE des agrégats : les codes eux-mêmes (marqueurs, pas du texte)
// et des compteurs.
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

final _code = RegExp(r'~[A-Za-z][0-9A-Za-z]{2}');

List<String> codes(String s) =>
    [for (final m in _code.allMatches(s)) m.group(0)!]..sort();

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final db = TdbDatabase.openFile(project.dbPath);
  final repo = TranslationRepository(db, locale: project.locale);
  final byCode = <String, int>{};
  var strings = 0, withCodes = 0, ai = 0, aiMismatch = 0, aiMissing = 0;
  for (final f in await repo.listFiles()) {
    final n = await repo.countSlots(f.id);
    for (final s in await repo.slots(f.id, limit: n)) {
      if (s.isAlias) continue;
      strings++;
      final c = codes(s.sourceText);
      if (c.isNotEmpty) withCodes++;
      for (final x in c) byCode[x] = (byCode[x] ?? 0) + 1;
      final t = s.translation;
      if (t != null && (t.authorId ?? '').startsWith('ai:')) {
        ai++;
        final tc = codes(t.text);
        if (tc.join() != c.join()) {
          aiMismatch++;
          if (tc.length < c.length) aiMissing++;
        }
      }
    }
  }
  print('strings=$strings withCodes=$withCodes');
  print(
      'codes: ${(byCode.entries.toList()..sort((x, y) => y.value - x.value)).take(30).map((e) => '${e.key}:${e.value}').join(' ')}');
  print('distinct=${byCode.length}');
  print('ai drafts=$ai codesMismatch=$aiMismatch (fewer codes: $aiMissing)');
  await db.close();
}
