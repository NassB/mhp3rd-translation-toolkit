import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

import 'string_table_file.dart';

/// Décode un fichier `string_table_a` déchiffré.
///
/// Structure : voir `docs/FORMATS/string_table_a.md` (source :
/// third_party/mhtools/src/dec/ExtractPluginA.java `extract` et layout
/// vérifié sur l'ID 17 réel : offsets de chaînes relatifs à la table,
/// offsets de tables absolus, tables contiguës, octet 0x00 final par table).
///
/// Les offsets stockés font foi. Tout layout non canonique (table ou chaîne
/// non contiguë, offset hors bornes, sentinelle absente) lève [FormatError] :
/// aucune tolérance non observée sur données réelles.
StringTableFile decodeStringTableA(Uint8List data, {int? fileId}) {
  final r = ByteReader(data, fileId: fileId);
  FormatError fail(String msg, int offset) =>
      FormatError(msg, offset: offset, fileId: fileId);

  final count = r.i32();
  if (count < 0 || count > (data.length - 8) ~/ 4) {
    throw fail('invalid tablesCount $count', 0);
  }
  final unknownHeader = r.i32();
  final tableOffsets = [for (var i = 0; i < count; i++) r.i32()];

  var expectedStart = 8 + 4 * count;
  final tables = <StringTable?>[];
  for (final t in tableOffsets) {
    if (t == -1) {
      tables.add(null);
      continue;
    }
    if (t != expectedStart) {
      throw fail(
        'table not contiguous (expected 0x'
        '${expectedStart.toRadixString(16)})',
        t < 0 ? 0 : t,
      );
    }
    r.seek(t);
    final offsets = <int>[];
    while (true) {
      final o = r.i32();
      if (o == -1) break;
      offsets.add(o);
    }
    final k = offsets.length;
    var next = 4 * k + 4; // premier offset canonique, relatif à la table
    final slots = <StringSlot>[];
    final firstIndexAt = <int, int>{};
    for (var i = 0; i < k; i++) {
      final o = offsets[i];
      final alias = firstIndexAt[o];
      if (alias == null) {
        if (o != next) {
          throw fail(
            'string offset 0x${o.toRadixString(16)} not contiguous '
            '(expected 0x${next.toRadixString(16)})',
            t + 4 * i,
          );
        }
        firstIndexAt[o] = i;
      }
      final abs = t + o;
      if (abs >= data.length) throw fail('string offset out of bounds', abs);
      var end = abs;
      while (end < data.length && data[end] != 0) {
        end++;
      }
      if (end >= data.length) throw fail('unterminated string', abs);
      slots.add(
        StringSlot(
          index: i,
          raw: Uint8List.sublistView(data, abs, end),
          aliasOf: alias,
        ),
      );
      if (alias == null) next = o + (end - abs) + 1;
    }
    final endByte = t + next;
    if (endByte >= data.length) throw fail('missing table end byte', endByte);
    if (data[endByte] != 0) throw fail('table end byte is not 0x00', endByte);
    expectedStart = endByte + 1;
    tables.add(StringTable(originalOffsets: offsets, slots: slots));
  }

  return StringTableFile(
    unknownHeader: unknownHeader,
    tables: tables,
    endData: Uint8List.sublistView(data, expectedStart),
  );
}
