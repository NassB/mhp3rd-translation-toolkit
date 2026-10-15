import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:test/test.dart';

import 'support/string_table_a_builder.dart';

Entry s(String v) => Entry.str(v.codeUnits);

void main() {
  void roundTrip(Uint8List data) {
    final f = decodeStringTableA(data);
    final out = encodeStringTableA(f);
    expect(out, data);
    expect(measureStringTableA(f), out.length);
  }

  test('round-trips null table, empty table, empty string, endData', () {
    roundTrip(
      buildStringTableA(
        [
          [s('ab'), s(''), s('c')],
          null,
          [],
          [s('z')],
        ],
        unknownHeader: 77,
        endData: [9, 8, 7],
      ),
    );
  });

  test('round-trips aliases', () {
    roundTrip(
      buildStringTableA([
        [s('ab'), const Entry.alias(0), s('c'), const Entry.alias(0)],
      ]),
    );
  });

  test('round-trips empty file and only-null tables', () {
    roundTrip(buildStringTableA([]));
    roundTrip(buildStringTableA([null, null]));
  });

  test('measure == encode length after a string grows', () {
    final f = decodeStringTableA(
      buildStringTableA([
        [s('ab'), const Entry.alias(0), s('c')],
        [s('x')],
      ]),
    );
    final t0 = f.tables[0]!;
    final edited = StringTableFile(
      unknownHeader: f.unknownHeader,
      tables: [
        StringTable(
          originalOffsets: t0.originalOffsets,
          slots: [
            StringSlot(index: 0, raw: Uint8List.fromList('abcdef'.codeUnits)),
            t0.slots[1],
            t0.slots[2],
          ],
        ),
        f.tables[1],
      ],
      endData: f.endData,
    );
    final out = encodeStringTableA(edited);
    expect(measureStringTableA(edited), out.length);
    final back = decodeStringTableA(out);
    expect(
      back.tables[0]!.slots.map((e) => String.fromCharCodes(e.raw)),
      ['abcdef', 'abcdef', 'c'],
    );
    expect(back.tables[0]!.slots[1].aliasOf, 0);
    expect(String.fromCharCodes(back.tables[1]!.slots.single.raw), 'x');
  });

  test('rejects a string containing 0x00', () {
    final f = StringTableFile(
      unknownHeader: 8,
      tables: [
        StringTable(
          originalOffsets: const [],
          slots: [
            StringSlot(index: 0, raw: Uint8List.fromList([65, 0, 66])),
          ],
        ),
      ],
      endData: Uint8List(0),
    );
    expect(() => encodeStringTableA(f), throwsA(isA<FormatError>()));
  });

  test('rejects invalid aliasOf (forward or chained)', () {
    StringTableFile withSlots(List<StringSlot> slots) => StringTableFile(
          unknownHeader: 8,
          tables: [StringTable(originalOffsets: const [], slots: slots)],
          endData: Uint8List(0),
        );
    final a = Uint8List.fromList([65]);
    expect(
      () => encodeStringTableA(
        withSlots([
          StringSlot(index: 0, raw: a, aliasOf: 1),
          StringSlot(index: 1, raw: a),
        ]),
      ),
      throwsA(isA<FormatError>()),
    );
    expect(
      () => encodeStringTableA(
        withSlots([
          StringSlot(index: 0, raw: a),
          StringSlot(index: 1, raw: a, aliasOf: 0),
          StringSlot(index: 2, raw: a, aliasOf: 1),
        ]),
      ),
      throwsA(isA<FormatError>()),
    );
  });
}
