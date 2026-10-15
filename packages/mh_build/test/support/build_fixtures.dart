// Fixtures partagées des tests de mh_build (synthétiques).
import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

/// Table 0 : [first], 'trois', alias de 0 ; table 1 nulle ; endData fixe de
/// 100 octets non nuls placé en fin de slot (2048 octets).
StringTableFile model({String first = 'un\ndeux'}) {
  final tables = [
    StringTable(
      originalOffsets: const [],
      slots: [
        StringSlot(index: 0, raw: b(first)),
        StringSlot(index: 1, raw: b('trois')),
        StringSlot(index: 2, raw: b(first), aliasOf: 0),
      ],
    ),
    null,
  ];
  // originalOffsets canoniques : on laisse l'encodeur les recalculer.
  final probe = encodeStringTableA(
    StringTableFile(unknownHeader: 8, tables: tables, endData: Uint8List(0)),
  );
  return decodeStringTableA(
    Uint8List.fromList([
      ...probe,
      ...Uint8List(2048 - probe.length - 100),
      ...List.filled(100, 0x5A),
    ]),
  );
}

Uint8List slotBytesOf(StringTableFile f) => encodeStringTableA(f);

MhtoolsDump dump(List<String> lines) => MhtoolsDump(
      fileListText: 'x.bin 0\nstring_table_0.txt\nstring_table_1.txt\n',
      tableTexts: ['${lines.join('\n')}\n', null],
      endData: Uint8List(0),
    );

DataBinEntry entry({bool encrypted = true}) => DataBinEntry(
      id: 1,
      lba: 5,
      slotBytes: 2048,
      sha1Plain: '',
      encrypted: encrypted,
    );
