// ignore_for_file: type=lint
// Contrôle local (TA3) : prompt + lot + analyse contre LM Studio, avec des
// phrases japonaises SYNTHÉTIQUES (jamais du texte du jeu).
import 'dart:convert';

import 'package:mh_formats/mh_formats.dart';
import 'package:mh_translate/mh_translate.dart';

Future<void> main(List<String> a) async {
  final units = [
    const TranslationUnit(id: 1, source: 'こんにちは。', maxBytes: 20),
    const TranslationUnit(id: 2, source: 'ありがとう\nございます。', maxBytes: 30),
    const TranslationUnit(id: 3, source: 'ハンターは森へ行く。', maxBytes: 40),
    const TranslationUnit(id: 4, source: 'お水をください。', maxBytes: 30),
    const TranslationUnit(id: 5, source: 'さようなら', maxBytes: 12),
    const TranslationUnit(id: 6, source: 'これはペンです。', maxBytes: 25),
  ];
  final batches = buildBatches(units);
  final c = OpenAiCompatibleClient(endpoint: Uri.parse(a[0]));
  try {
    for (final b in batches) {
      final msgs = buildMessages(
        b,
        context: const BatchContext(
          glossary: [
            GlossaryEntry(
                sourceTerm: 'ハンター', targetTerm: 'Chasseur', mandatory: true),
          ],
        ),
      );
      final sw = Stopwatch()..start();
      final r = await c.chat(
        model: a[1],
        messages: msgs,
        maxTokens: 2000,
        jsonSchema: translationSchema(),
      );
      final p = parseTranslations(r.content, b);
      print('batch of ${b.units.length}: ${sw.elapsedMilliseconds} ms, '
          'est=${b.estimatedTokens}, prompt=${r.promptTokens}, out=${r.completionTokens}, '
          'complete=${p.complete}');
      for (final u in b.units) {
        final t = p.translations[u.id];
        final bytes = t == null ? -1 : utf8.encode(t).length;
        print(
            '  ${u.id}: "${t?.replaceAll('\n', '\n')}" ($bytes/${u.maxBytes} B, '
            'newlines ${t?.split('\n').length ?? 0 - 1}/${u.source.split('\n').length})');
      }
    }
  } on TranslateError catch (e) {
    print('error: $e');
  } finally {
    c.close();
  }
}
