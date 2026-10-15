import 'dart:io';

import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ai_settings'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('defaults when the file is absent', () {
    final s = AiSettings.load(tmp.path);
    expect(s.endpoint, AiSettings.defaultEndpoint);
    expect(s.model, isNull);
  });

  test('save then load round-trips and never writes a key', () {
    const AiSettings(endpoint: 'http://127.0.0.1:1235/v1', model: 'm')
        .save(tmp.path);
    final text = File('${tmp.path}/ai.json').readAsStringSync();
    expect(text, isNot(contains('key')));
    final s = AiSettings.load(tmp.path);
    expect((s.endpoint, s.model), ('http://127.0.0.1:1235/v1', 'm'));
  });

  test('corrupt or oddly typed files give the defaults', () {
    final f = File('${tmp.path}/ai.json');
    for (final content in [
      'pas du json',
      '[1,2]',
      '{"endpoint":3,"model":4}',
    ]) {
      f.writeAsStringSync(content);
      final s = AiSettings.load(tmp.path);
      expect(s.endpoint, AiSettings.defaultEndpoint, reason: content);
      expect(s.model, isNull, reason: content);
    }
  });

  test('copyWith keeps what is not replaced', () {
    const base = AiSettings(endpoint: 'http://a/v1', model: 'm');
    expect(base.copyWith(model: 'n').endpoint, 'http://a/v1');
    expect(base.copyWith(endpoint: 'http://b/v1').model, 'm');
  });
}
