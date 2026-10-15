import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

/// Entrée de table synthétique : chaîne ou alias d'un index précédent.
final class Entry {
  const Entry.str(this.bytes) : aliasOf = null;
  const Entry.alias(int this.aliasOf) : bytes = const [];
  final List<int> bytes;
  final int? aliasOf;
}

/// Construit un `string_table_a` synthétique canonique
/// (layout de docs/FORMATS/string_table_a.md). `null` = table nulle.
Uint8List buildStringTableA(
  List<List<Entry>?> tables, {
  int unknownHeader = 8,
  List<int> endData = const [],
}) {
  final w = ByteWriter()
    ..u32(tables.length)
    ..u32(unknownHeader);
  var pos = 8 + 4 * tables.length;
  final blobs = <Uint8List>[];
  for (final t in tables) {
    if (t == null) {
      w.u32(0xFFFFFFFF);
      continue;
    }
    final tw = ByteWriter();
    final offs = <int>[];
    final strings = ByteWriter();
    var next = 4 * t.length + 4;
    for (final e in t) {
      if (e.aliasOf != null) {
        offs.add(offs[e.aliasOf!]);
      } else {
        offs.add(next);
        strings
          ..bytes(Uint8List.fromList(e.bytes))
          ..u8(0);
        next += e.bytes.length + 1;
      }
    }
    for (final o in offs) {
      tw.u32(o);
    }
    tw
      ..u32(0xFFFFFFFF)
      ..bytes(strings.toBytes())
      ..u8(0);
    final blob = tw.toBytes();
    w.u32(pos);
    pos += blob.length;
    blobs.add(blob);
  }
  for (final b in blobs) {
    w.bytes(b);
  }
  w.bytes(Uint8List.fromList(endData));
  return w.toBytes();
}
