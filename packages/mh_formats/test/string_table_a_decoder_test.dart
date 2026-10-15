import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:test/test.dart';

import 'support/string_table_a_builder.dart';

Entry s(String v) => Entry.str(v.codeUnits);

void main() {
  test('decodes tables, null table, empty table, empty string, endData', () {
    final data = buildStringTableA(
      [
        [s('ab'), s(''), s('c')],
        null,
        [],
        [s('z')],
      ],
      unknownHeader: 8,
      endData: [9, 8, 7],
    );
    final f = decodeStringTableA(data);
    expect(f.unknownHeader, 8);
    expect(f.tables.length, 4);
    expect(f.tables[1], isNull);
    expect(f.tables[2]!.slots, isEmpty);
    final t0 = f.tables[0]!;
    expect(t0.originalOffsets, [16, 19, 20]);
    expect(t0.slots.map((e) => String.fromCharCodes(e.raw)), ['ab', '', 'c']);
    expect(String.fromCharCodes(f.tables[3]!.slots.single.raw), 'z');
    expect(f.endData, [9, 8, 7]);
  });

  test('keeps unknownHeader as is', () {
    final f = decodeStringTableA(buildStringTableA([null], unknownHeader: 77));
    expect(f.unknownHeader, 77);
    expect(f.endData, isEmpty);
  });

  test('detects aliases', () {
    final f = decodeStringTableA(
      buildStringTableA([
        [s('a'), s('b'), const Entry.alias(0)],
      ]),
    );
    final slots = f.tables.single!.slots;
    expect(slots.map((e) => e.aliasOf), [null, null, 0]);
    expect(slots[2].raw, slots[0].raw);
    expect(
      f.tables.single!.originalOffsets[2],
      f.tables.single!.originalOffsets[0],
    );
  });

  test('truncated file throws FormatError', () {
    final data = buildStringTableA([
      [s('abc'), s('def')],
    ]);
    for (final n in [0, 4, 9, data.length - 2, data.length - 1]) {
      expect(
        () => decodeStringTableA(Uint8List.sublistView(data, 0, n)),
        throwsA(isA<FormatError>()),
        reason: 'cut at $n',
      );
    }
  });

  test('string offset out of bounds throws', () {
    final data = buildStringTableA([
      [s('a')],
    ]);
    ByteData.sublistView(data).setInt32(12, 0x10000, Endian.little);
    expect(() => decodeStringTableA(data), throwsA(isA<FormatError>()));
  });

  test('non contiguous string offset throws', () {
    final data = buildStringTableA([
      [s('a'), s('b')],
    ]);
    ByteData.sublistView(data).setInt32(16, 0x20, Endian.little);
    expect(() => decodeStringTableA(data), throwsA(isA<FormatError>()));
  });

  test('non contiguous table offset throws', () {
    final data = buildStringTableA([
      [s('a')],
    ]);
    ByteData.sublistView(data).setInt32(8, 100, Endian.little);
    expect(() => decodeStringTableA(data), throwsA(isA<FormatError>()));
  });

  test('absurd tablesCount throws', () {
    final data = Uint8List(16);
    ByteData.sublistView(data).setInt32(0, 1000, Endian.little);
    expect(() => decodeStringTableA(data), throwsA(isA<FormatError>()));
  });
}
