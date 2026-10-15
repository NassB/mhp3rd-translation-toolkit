import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';

/// Nom du fichier de métadonnées d'un projet.
const String projectFileName = 'project.json';

/// Nom de la base de traduction d'un projet.
const String projectDbName = 'tdb.sqlite';

/// Configuration par défaut du registre des versions.
const String defaultVersionsConfig = 'config/game_versions.yaml';

/// Projet de traduction : un dossier avec `project.json` et `tdb.sqlite`.
final class Project {
  /// Voir les champs.
  const Project({
    required this.dir,
    required this.isoPath,
    required this.versionId,
    required this.locale,
  });

  /// Dossier du projet.
  final String dir;

  /// Chemin absolu de l'ISO source (jamais modifiée).
  final String isoPath;

  /// ID de version du jeu (registre).
  final String versionId;

  /// Locale cible (`fr`, `en`…).
  final String locale;

  /// Chemin de la base SQLite.
  String get dbPath => '$dir/$projectDbName';

  /// Écrit `project.json` dans [dir] (le dossier doit exister).
  void save() => File('$dir/$projectFileName').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
              'iso': isoPath,
              'version': versionId,
              'locale': locale,
            })}\n',
      );

  /// Relit un projet. Lève [IsoError] si le dossier n'est pas un projet.
  static Project load(String dir) {
    final f = File('$dir/$projectFileName');
    if (!f.existsSync()) {
      throw IsoError('not a project (missing $projectFileName): $dir');
    }
    try {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      return Project(
        dir: dir,
        isoPath: j['iso']! as String,
        versionId: j['version']! as String,
        locale: j['locale']! as String,
      );
    } on Object {
      throw IsoError('invalid $projectFileName in $dir');
    }
  }
}

/// ISO ouverte avec l'index de `DATA.BIN` et un lecteur de slots déchiffrés.
final class IsoSession {
  IsoSession._(this.image, this._raf, this.index, this._base);

  /// Ouvre [isoPath] (MD5 et offset vérifiés) et construit l'index.
  static Future<IsoSession> open(String isoPath, String config) async {
    final img = await FileIsoImage.open(
      isoPath,
      GameVersionRegistry.fromFile(config),
    );
    final raf = File(isoPath).openSync();
    try {
      final base = img.dataBin.offset;
      Uint8List readAt(int offset, int length) =>
          _readAt(raf, base + offset, length);
      return IsoSession._(
        img,
        raf,
        DataBinIndex.build(readAt, img.dataBin.size),
        base,
      );
    } on Object {
      raf.closeSync();
      img.close();
      rethrow;
    }
  }

  /// Image ISO vérifiée.
  final FileIsoImage image;

  /// Index de `DATA.BIN`.
  final DataBinIndex index;

  final RandomAccessFile _raf;
  final int _base;

  /// Slot d'origine de [e], déchiffré si besoin.
  Uint8List readPlain(DataBinEntry e) {
    final raw = _readAt(_raf, _base + e.offset, e.slotBytes);
    return e.encrypted ? const DataCipher().decrypt(raw, e.lba) : raw;
  }

  /// Ferme l'ISO.
  void close() {
    _raf.closeSync();
    image.close();
  }
}

Uint8List _readAt(RandomAccessFile raf, int position, int length) {
  raf.setPositionSync(position);
  final buf = Uint8List(length);
  var got = 0;
  while (got < length) {
    final n = raf.readIntoSync(buf, got);
    if (n == 0) throw FormatError('short read of DATA.BIN', offset: position);
    got += n;
  }
  return buf;
}
