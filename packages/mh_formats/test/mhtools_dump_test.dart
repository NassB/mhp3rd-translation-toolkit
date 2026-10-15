import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:test/test.dart';

import 'support/string_table_a_builder.dart';

Entry s(String v) => Entry.str(v.codeUnits);

StringTableFile sample() => decodeStringTableA(
      buildStringTableA(
        [
          [s('ab'), s(''), s('l1\nl2'), const Entry.alias(0)],
          null,
          [],
          [s('z')],
        ],
        unknownHeader: 5,
        endData: [9, 8],
      ),
    );

MhtoolsDump dumpOf(StringTableFile f) =>
    exportMhtoolsDump(f, name: 'x.bin', size: 100);

MhtoolsDump withTexts(List<String?> t) => MhtoolsDump(
      fileListText: '',
      tableTexts: t,
      endData: Uint8List(0),
    );

void main() {
  test('export format matches mhtools conventions', () {
    final d = dumpOf(sample());
    expect(
      d.fileListText,
      'x.bin 100\nstring_table_0.txt\nstring_table_1.txt\n'
      'string_table_2.txt\nstring_table_3.txt\nenddata.bin\n',
    );
    expect(d.tableTexts[0], 'ab\n<EMPTY STRING>\nl1<NEWLINE>l2\nab\n');
    expect(d.tableTexts[1], isNull);
    expect(d.tableTexts[2], '');
    expect(d.endData, [9, 8]);
  });

  test('export then import is bit-exact', () {
    final f = sample();
    final back = importMhtoolsDump(f, dumpOf(f));
    expect(encodeStringTableA(back), encodeStringTableA(f));
  });

  test('edited text re-encodes with measure == length and keeps alias', () {
    final f = sample();
    final d = dumpOf(f);
    final edited = MhtoolsDump(
      fileListText: d.fileListText,
      tableTexts: [
        'été\r\n<EMPTY STRING>\r\nnew<NEWLINE>x\r\nété\r\n',
        null,
        '',
        '﻿q',
      ],
      endData: d.endData,
    );
    final g = importMhtoolsDump(f, edited);
    expect(g.tables[0]!.slots[3].aliasOf, 0);
    expect(g.tables[0]!.slots[1].raw, isEmpty);
    expect(g.tables[0]!.slots[2].raw, 'new\nx'.codeUnits);
    expect(g.tables[3]!.slots[0].raw, 'q'.codeUnits);
    final out = encodeStringTableA(g);
    expect(measureStringTableA(g), out.length);
    expect(decodeStringTableA(out).tables[0]!.slots[0].raw.length, 5);
  });

  test('rejects wrong line count, table count, nullness', () {
    final f = sample();
    expect(
      () => importMhtoolsDump(f, withTexts(['a\n', null, '', 'z\n'])),
      throwsA(isA<FormatError>()),
    );
    expect(
      () => importMhtoolsDump(f, withTexts([null])),
      throwsA(isA<FormatError>()),
    );
    expect(
      () => importMhtoolsDump(
        f,
        withTexts(['a\nb\nc\na\n', 'x\n', '', 'z\n']),
      ),
      throwsA(isA<FormatError>()),
    );
  });

  test('rejects diverging alias, NUL and mixed empty marker', () {
    final f = sample();
    for (final bad in [
      'a\nb\nc\nDIFF\n',
      'a\nb\nc\n a\n',
      'a\nb\nc\u0000\na\n',
      '<EMPTY STRING>x\nb\nc\n<EMPTY STRING>x\n',
    ]) {
      expect(
        () => importMhtoolsDump(f, withTexts([bad, null, '', 'z\n'])),
        throwsA(isA<FormatError>()),
        reason: bad,
      );
    }
  });

  test('export rejects invalid UTF-8, literal markers, trailing CR', () {
    for (final raw in [
      [0xFF, 0xFE],
      '<NEWLINE>'.codeUnits,
      'a\r'.codeUnits,
    ]) {
      final f = decodeStringTableA(
        buildStringTableA([
          [Entry.str(raw)],
        ]),
      );
      expect(() => dumpOf(f), throwsA(isA<FormatError>()));
    }
  });
}
