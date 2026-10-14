import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

/// Fichier synthétique à placer dans l'ISO de test.
final class FakeFile {
  const FakeFile(this.path, this.lba, this.size);

  /// Chemin `A/B/NAME` (sans suffixe de version).
  final String path;
  final int lba;
  final int size;
}

/// Construit une ISO 9660 synthétique minimale (fixture, aucune donnée réelle).
///
/// Les répertoires occupent un secteur chacun à partir du LBA 18 ; les
/// fichiers sont placés aux LBA demandés (contenu : octets nuls).
Uint8List buildIso(List<FakeFile> files, {bool validPvd = true}) {
  // Arbre : chemin de répertoire ('' = racine) -> nom -> (String | FakeFile).
  final dirs = <String, Map<String, Object>>{'': {}};
  for (final f in files) {
    final parts = f.path.split('/');
    var cur = '';
    for (var i = 0; i < parts.length - 1; i++) {
      final next = cur.isEmpty ? parts[i] : '$cur/${parts[i]}';
      dirs[cur]![parts[i]] = next;
      dirs.putIfAbsent(next, () => {});
      cur = next;
    }
    dirs[cur]![parts.last] = f;
  }
  final dirPaths = dirs.keys.toList();
  final dirLba = {
    for (var i = 0; i < dirPaths.length; i++) dirPaths[i]: 18 + i,
  };
  var totalSectors = 18 + dirPaths.length;
  for (final f in files) {
    final end = f.lba + alignUp(f.size, sectorSize) ~/ sectorSize;
    if (end > totalSectors) totalSectors = end;
  }
  final image = Uint8List(totalSectors * sectorSize);

  Uint8List record(List<int> name, int lba, int size, {required bool dir}) {
    var len = 33 + name.length;
    if (len.isOdd) len++;
    final r = Uint8List(len);
    final v = ByteData.sublistView(r);
    r[0] = len;
    v.setUint32(2, lba, Endian.little);
    v.setUint32(6, lba);
    v.setUint32(10, size, Endian.little);
    v.setUint32(14, size);
    r[25] = dir ? 2 : 0;
    r[32] = name.length;
    r.setRange(33, 33 + name.length, name);
    return r;
  }

  for (final dp in dirPaths) {
    var pos = dirLba[dp]! * sectorSize;
    void put(Uint8List r) {
      image.setRange(pos, pos + r.length, r);
      pos += r.length;
    }

    put(record([0], dirLba[dp]!, sectorSize, dir: true));
    put(record([1], dirLba[dp]!, sectorSize, dir: true));
    for (final e in dirs[dp]!.entries) {
      final v = e.value;
      if (v is String) {
        put(record(latin1.encode(e.key), dirLba[v]!, sectorSize, dir: true));
      } else {
        final f = v as FakeFile;
        put(record(latin1.encode('${e.key};1'), f.lba, f.size, dir: false));
      }
    }
  }

  const pvd = 16 * sectorSize;
  image[pvd] = 1;
  image.setRange(pvd + 1, pvd + 6, ascii.encode(validPvd ? 'CD001' : 'XXXXX'));
  image[pvd + 6] = 1;
  // Enregistrement racine de 34 octets (nom d'un octet : 0x00).
  final rootRec = record([0], dirLba['']!, sectorSize, dir: true);
  image.setRange(pvd + 156, pvd + 190, rootRec.sublist(0, 34));
  return image;
}
