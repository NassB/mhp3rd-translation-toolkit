import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

import 'iso_entry.dart';

/// Lecture aléatoire de [length] octets à partir de [offset].
typedef IsoReadAt = Uint8List Function(int offset, int length);

/// Parseur ISO 9660 minimal (lecture seule).
///
/// Structures lues en little-endian (champs « both-endian » : seule la moitié
/// LE est utilisée). Source : ECMA-119, norme publique.
///
/// Descripteur de volume primaire (secteur 16, ECMA-119 §8.4) :
///
/// | Offset | Taille | Champ                                   |
/// |--------|--------|-----------------------------------------|
/// | 0      | 1      | type (1 = primaire)                     |
/// | 1      | 5      | identifiant `CD001`                     |
/// | 6      | 1      | version (1)                             |
/// | 156    | 34     | enregistrement du répertoire racine     |
///
/// Enregistrement de répertoire (ECMA-119 §9.1) :
///
/// | Offset | Taille | Champ                                   |
/// |--------|--------|-----------------------------------------|
/// | 0      | 1      | longueur de l'enregistrement (0 = pad)  |
/// | 2      | 4      | LBA de l'extent (LE)                    |
/// | 10     | 4      | taille des données (LE)                 |
/// | 25     | 1      | drapeaux (bit 1 = répertoire)           |
/// | 32     | 1      | longueur du nom                         |
/// | 33     | n      | nom (`.` = 0x00, `..` = 0x01)           |
final class Iso9660 {
  /// Ouvre une image via [_readAt] ; [totalLength] sert aux bornes.
  Iso9660(this._readAt, this.totalLength) {
    final pvd = _read(_pvdOffset, sectorSize);
    if (pvd[0] != 1 ||
        ascii.decode(pvd.sublist(1, 6), allowInvalid: true) != 'CD001' ||
        pvd[6] != 1) {
      throw const IsoError(
        'invalid primary volume descriptor',
        offset: _pvdOffset,
      );
    }
    root = _parseRecord(pvd, 156, _pvdOffset, keepDots: true)!;
    if (!root.isDirectory) {
      throw const IsoError(
        'root record is not a directory',
        offset: _pvdOffset,
      );
    }
  }

  /// Ouvre une image entièrement en mémoire.
  factory Iso9660.fromBytes(Uint8List image) => Iso9660(
        (offset, length) =>
            Uint8List.sublistView(image, offset, offset + length),
        image.length,
      );

  static const int _pvdOffset = 16 * sectorSize;

  final IsoReadAt _readAt;

  /// Taille totale de l'image en octets.
  final int totalLength;

  /// Entrée du répertoire racine.
  late final IsoEntry root;

  /// Retrouve l'entrée de [path] (séparateur `/`, casse ignorée).
  ///
  /// Lève [IsoError] si un composant est absent.
  IsoEntry locate(String path) {
    var current = root;
    for (final part in path.split('/').where((p) => p.isNotEmpty)) {
      if (!current.isDirectory) {
        throw IsoError('not a directory: ${current.name} (in $path)');
      }
      final wanted = part.toUpperCase();
      IsoEntry? next;
      for (final e in list(current)) {
        if (e.name.toUpperCase() == wanted) {
          next = e;
          break;
        }
      }
      if (next == null) throw IsoError('path not found: $path');
      current = next;
    }
    return current;
  }

  /// Liste le contenu de [dir] (sans `.` ni `..`).
  List<IsoEntry> list(IsoEntry dir) {
    if (!dir.isDirectory) throw IsoError('not a directory: ${dir.name}');
    final data = _read(dir.offset, dir.size);
    final out = <IsoEntry>[];
    var pos = 0;
    while (pos < data.length) {
      final len = data[pos];
      if (len == 0) {
        // Les enregistrements ne franchissent pas les frontières de secteur.
        pos = alignUp(pos + 1, sectorSize);
        continue;
      }
      final entry = _parseRecord(data, pos, dir.offset + pos);
      if (entry != null) out.add(entry);
      pos += len;
    }
    return out;
  }

  Uint8List _read(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > totalLength) {
      throw IsoError(
        'read of $length byte(s) out of image bounds',
        offset: offset,
      );
    }
    return _readAt(offset, length);
  }

  /// Décode l'enregistrement à [pos] de [buf] ; `null` pour `.` et `..`
  /// sauf si [keepDots]. [absOffset] ne sert qu'aux messages d'erreur.
  IsoEntry? _parseRecord(
    Uint8List buf,
    int pos,
    int absOffset, {
    bool keepDots = false,
  }) {
    final len = buf[pos];
    if (len < 34 || pos + len > buf.length) {
      throw IsoError('malformed directory record', offset: absOffset);
    }
    final nameLen = buf[pos + 32];
    if (33 + nameLen > len) {
      throw IsoError(
        'directory record name overflows record',
        offset: absOffset,
      );
    }
    final nameBytes = buf.sublist(pos + 33, pos + 33 + nameLen);
    if (!keepDots && nameLen == 1 && nameBytes[0] <= 1) return null;
    final view = ByteData.sublistView(buf, pos, pos + len);
    var name = latin1.decode(nameBytes);
    final semi = name.indexOf(';');
    if (semi >= 0) name = name.substring(0, semi);
    return IsoEntry(
      name: name,
      lba: view.getUint32(2, Endian.little),
      size: view.getUint32(10, Endian.little),
      isDirectory: view.getUint8(25) & 0x02 != 0,
    );
  }
}
