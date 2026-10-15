// ignore_for_file: type=lint
// Contrôle local (TA2) : le vrai client contre le LM Studio de la machine, avec
// des phrases japonaises SYNTHÉTIQUES (jamais du texte du jeu).
// Usage : dart run packages/mh_translate/tool/real_chat.dart <endpoint> <model>
import 'package:mh_translate/mh_translate.dart';

Future<void> main(List<String> a) async {
  final c = OpenAiCompatibleClient(endpoint: Uri.parse(a[0]));
  try {
    final models = await c.listModels();
    print(
        'models: ${models.length} (${models.contains(a[1]) ? 'target present' : 'target ABSENT'})');
    final sw = Stopwatch()..start();
    final r = await c.chat(
      model: a[1],
      messages: const [
        ChatMessage.system(
            'Traduis du japonais vers le français. Réponds uniquement par la traduction.'),
        ChatMessage.user('ありがとう\nございます。'),
      ],
      maxTokens: 300,
    );
    print('chat: ${sw.elapsedMilliseconds} ms, finish=${r.finishReason}, '
        'prompt=${r.promptTokens}, completion=${r.completionTokens}');
    print('content: ${r.content.replaceAll('\n', '\n')}');
  } on TranslateError catch (e) {
    print('error: $e');
  } finally {
    c.close();
  }
}
