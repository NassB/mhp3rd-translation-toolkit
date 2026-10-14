import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:yaml/yaml.dart';

/// Version connue du jeu (une entrée de `config/game_versions.yaml`).
///
/// Source : docs/ARCHITECTURE.md §4 « Registre des versions »,
/// valeurs issues de third_party/mhp3-translation-tools/patch-iso.py.
final class GameVersion {
  /// Crée une version.
  const GameVersion({
    required this.id,
    required this.platform,
    required this.isoMd5,
    required this.databinIsoOffset,
  });

  /// Identifiant (ex. `ULJM05800`).
  final String id;

  /// Plateforme (`psp`, `ps3`).
  final String platform;

  /// MD5 de l'ISO complet, hexadécimal minuscule.
  final String isoMd5;

  /// Offset attendu de `DATA.BIN` dans l'ISO, en octets.
  final int databinIsoOffset;
}

/// Registre des versions connues.
final class GameVersionRegistry {
  /// Crée un registre à partir de [versions].
  const GameVersionRegistry(this.versions);

  /// Lit un registre depuis le texte YAML de `config/game_versions.yaml`.
  ///
  /// Lève [IsoError] si le document ou une entrée est mal formé.
  factory GameVersionRegistry.parse(String yamlText) {
    final Object? doc;
    try {
      doc = loadYaml(yamlText);
    } on YamlException catch (e) {
      throw IsoError('invalid game versions YAML: ${e.message}');
    }
    if (doc is! YamlList) {
      throw const IsoError('game versions YAML must be a list');
    }
    final out = <GameVersion>[];
    for (final item in doc) {
      if (item is! YamlMap) {
        throw const IsoError('game version entry must be a map');
      }
      final id = _string(item, 'id');
      final md5 = _string(item, 'iso_md5').toLowerCase();
      if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(md5)) {
        throw IsoError('invalid iso_md5 for $id');
      }
      final offset = item['databin_iso_offset'];
      if (offset is! int || offset < 0 || offset % sectorSize != 0) {
        throw IsoError('invalid databin_iso_offset for $id');
      }
      out.add(
        GameVersion(
          id: id,
          platform: _string(item, 'platform'),
          isoMd5: md5,
          databinIsoOffset: offset,
        ),
      );
    }
    return GameVersionRegistry(List.unmodifiable(out));
  }

  /// Lit un registre depuis un fichier YAML.
  factory GameVersionRegistry.fromFile(String path) =>
      GameVersionRegistry.parse(File(path).readAsStringSync());

  /// Versions connues.
  final List<GameVersion> versions;

  /// Version dont l'ISO a le MD5 [md5] (hexadécimal), ou `null`.
  GameVersion? byMd5(String md5) {
    final wanted = md5.toLowerCase();
    for (final v in versions) {
      if (v.isoMd5 == wanted) return v;
    }
    return null;
  }

  static String _string(YamlMap map, String key) {
    final v = map[key];
    if (v is! String || v.isEmpty) {
      throw IsoError('missing or invalid "$key" in game version entry');
    }
    return v;
  }
}
