import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

import 'string_table_file.dart';

/// Vérifie les invariants d'écriture d'une table (alias valides, pas de 0).
void _validate(StringTable t, int tableIndex, int? fileId) {
  FormatError fail(String msg) =>
      FormatError('table $tableIndex: $msg', offset: 0, fileId: fileId);
  for (var i = 0; i < t.slots.length; i++) {
    final s = t.slots[i];
    final a = s.aliasOf;
    if (a != null) {
      if (a < 0 || a >= i || t.slots[a].aliasOf != null) {
        throw fail('slot $i has invalid aliasOf $a');
      }
    } else if (s.raw.contains(0)) {
      throw fail('slot $i contains a 0x00 byte');
    }
  }
}

/// Taille exacte en octets de `encodeStringTableA(file)`.
///
/// Layout : voir `docs/FORMATS/string_table_a.md` (source :
/// third_party/mhtools/src/enc/RebuildPluginA.java `compile`, avec offsets
/// d'alias conservés et layout vérifié sur l'ID 17 réel).
int measureStringTableA(StringTableFile file, {int? fileId}) {
  var size = 8 + 4 * file.tables.length;
  for (var j = 0; j < file.tables.length; j++) {
    final t = file.tables[j];
    if (t == null) continue;
    _validate(t, j, fileId);
    size += 4 * t.slots.length + 4 + 1; // offsets, sentinelle, octet de fin
    for (final s in t.slots) {
      if (s.aliasOf == null) size += s.raw.length + 1;
    }
  }
  return size + file.endData.length;
}

/// Encode un [StringTableFile] en `string_table_a`.
///
/// Les offsets sont recalculés (canoniques : contigus, relatifs à la table) ;
/// les alias partagent l'offset de leur premier slot. Sur un fichier décodé
/// non modifié, le résultat est identique bit à bit à l'original (le décodeur
/// n'accepte que le layout canonique).
Uint8List encodeStringTableA(StringTableFile file, {int? fileId}) {
  final total = measureStringTableA(file, fileId: fileId);
  final w = ByteWriter()
    ..u32(file.tables.length)
    ..u32(file.unknownHeader & 0xFFFFFFFF);

  var pos = 8 + 4 * file.tables.length;
  for (final t in file.tables) {
    if (t == null) {
      w.u32(0xFFFFFFFF);
      continue;
    }
    w.u32(pos);
    pos += 4 * t.slots.length + 5;
    for (final s in t.slots) {
      if (s.aliasOf == null) pos += s.raw.length + 1;
    }
  }

  for (final t in file.tables) {
    if (t == null) continue;
    final offs = <int>[];
    var next = 4 * t.slots.length + 4;
    for (final s in t.slots) {
      final a = s.aliasOf;
      if (a != null) {
        offs.add(offs[a]);
      } else {
        offs.add(next);
        next += s.raw.length + 1;
      }
    }
    for (final o in offs) {
      w.u32(o);
    }
    w.u32(0xFFFFFFFF);
    for (final s in t.slots) {
      if (s.aliasOf != null) continue;
      w
        ..bytes(s.raw)
        ..u8(0);
    }
    w.u8(0);
  }
  w.bytes(file.endData);

  final out = w.toBytes();
  assert(out.length == total, 'measure/encode mismatch');
  return out;
}
