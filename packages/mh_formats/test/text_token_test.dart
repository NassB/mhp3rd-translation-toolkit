import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  void roundTrip(String s) {
    final raw = b(s);
    final tokens = tokenizeText(raw);
    expect(detokenizeText(tokens), raw);
    expect(tokensByteLength(tokens), raw.length);
  }

  test('splits text and newlines canonically', () {
    expect(tokenizeText(b('ab\ncd')), [
      const TextToken('ab'),
      const NewlineToken(),
      const TextToken('cd'),
    ]);
    expect(tokenizeText(b('\n\nx\n')), [
      const NewlineToken(),
      const NewlineToken(),
      const TextToken('x'),
      const NewlineToken(),
    ]);
    expect(tokenizeText(b('')), isEmpty);
  });

  test('round-trips edge cases with exact byte length', () {
    for (final s in [
      '',
      'a',
      '\n',
      'a\n',
      '\na',
      'a\n\nb',
      '~%d~\r\n',
      '≪日本語≫\n★',
    ]) {
      roundTrip(s);
    }
  });

  test('other control bytes stay in text', () {
    expect(tokenizeText(b('a\u0001b')), [const TextToken('a\u0001b')]);
  });

  test('rejects invalid UTF-8', () {
    expect(
      () => tokenizeText(Uint8List.fromList([0x61, 0xFF])),
      throwsA(isA<FormatError>()),
    );
  });

  test('rejects text tokens with newline or NUL', () {
    expect(
      () => detokenizeText([const TextToken('a\nb')]),
      throwsA(isA<FormatError>()),
    );
    expect(
      () => detokenizeText([const TextToken('a\u0000')]),
      throwsA(isA<FormatError>()),
    );
  });

  test('StringSlot.tokens', () {
    final slot = StringSlot(index: 0, raw: b('x\ny'));
    expect(slot.tokens.length, 3);
  });
}
