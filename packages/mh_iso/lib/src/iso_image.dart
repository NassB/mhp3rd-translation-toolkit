import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';

import 'game_version.dart';
import 'iso9660.dart';
import 'iso_entry.dart';

/// Chemin de `DATA.BIN` dans l'ISO (docs/ARCHITECTURE.md §4).
const String dataBinIsoPath = 'PSP_GAME/USRDIR/DATA.BIN';

/// Image ISO identifiée et vérifiée (docs/ARCHITECTURE.md §4, « Interface »).
abstract interface class IsoImage {
  /// Chemin du fichier ISO.
  String get path;

  /// Version reconnue du jeu.
  GameVersion get version;

  /// Entrée de `DATA.BIN`, dont l'offset est égal à celui du registre.
  IsoEntry get dataBin;

  /// Retrouve l'entrée de [path] (ex. `PSP_GAME/USRDIR/DATA.BIN`).
  IsoEntry locate(String path);

  /// Lit `[start, end)` octets de [e] (relatifs au début du fichier).
  Stream<List<int>> openRead(IsoEntry e, {int start = 0, int? end});

  /// Copie l'ISO vers [outPath] (nouveau fichier) avant tout patch.
  ///
  /// La source n'est jamais ouverte en écriture. Lève [IsoError] si
  /// [outPath] existe déjà (ce qui couvre aussi la source elle-même).
  Future<IsoImage> cloneTo(String outPath);

  /// Libère le fichier ouvert.
  void close();
}

/// [IsoImage] adossée à un fichier local, ouvert en lecture seule.
final class FileIsoImage implements IsoImage {
  FileIsoImage._(this.path, this.version, this._raf, this._iso, this.dataBin);

  /// Ouvre [path], calcule son MD5 en flux, retrouve la version dans
  /// [registry] et vérifie l'offset de `DATA.BIN` (AGENTS.md §4.3).
  ///
  /// Lève [IsoError] si la version est inconnue ou l'offset diverge.
  static Future<FileIsoImage> open(
    String path,
    GameVersionRegistry registry,
  ) async {
    final md5Hex = (await md5.bind(File(path).openRead()).first).toString();
    final version = registry.byMd5(md5Hex);
    if (version == null) {
      throw IsoError('unknown ISO (md5 $md5Hex not in registry): $path');
    }
    return _openVerified(path, version);
  }

  static FileIsoImage _openVerified(String path, GameVersion version) {
    final raf = File(path).openSync();
    try {
      final iso = Iso9660(
        (offset, length) {
          raf.setPositionSync(offset);
          final buf = raf.readSync(length);
          if (buf.length != length) {
            throw IsoError('short read of ISO file', offset: offset);
          }
          return buf;
        },
        raf.lengthSync(),
      );
      final entry = iso.locate(dataBinIsoPath);
      if (entry.offset != version.databinIsoOffset) {
        throw IsoError(
          'DATA.BIN offset mismatch for ${version.id}: ISO 9660 gives '
          '0x${entry.offset.toRadixString(16)}, registry expects '
          '0x${version.databinIsoOffset.toRadixString(16)}',
          offset: entry.offset,
        );
      }
      return FileIsoImage._(path, version, raf, iso, entry);
    } on Object {
      raf.closeSync();
      rethrow;
    }
  }

  @override
  final String path;

  @override
  final GameVersion version;

  @override
  final IsoEntry dataBin;

  final RandomAccessFile _raf;
  final Iso9660 _iso;

  @override
  IsoEntry locate(String path) => _iso.locate(path);

  @override
  Stream<List<int>> openRead(IsoEntry e, {int start = 0, int? end}) {
    final stop = end ?? e.size;
    if (start < 0 || stop < start || stop > e.size) {
      throw IsoError(
        'read range [$start, $stop) outside ${e.name} (size ${e.size})',
        offset: e.offset + start,
      );
    }
    return File(path).openRead(e.offset + start, e.offset + stop);
  }

  @override
  Future<IsoImage> cloneTo(String outPath) async {
    if (File(outPath).existsSync() || Link(outPath).existsSync()) {
      throw IsoError('clone target already exists: $outPath');
    }
    final sink = File(outPath).openWrite();
    try {
      await sink.addStream(File(path).openRead());
    } finally {
      await sink.close();
    }
    return _openVerified(outPath, version);
  }

  @override
  void close() => _raf.closeSync();
}
