import 'package:mh_binary/mh_binary.dart';

/// Entrée (fichier ou répertoire) d'une image ISO 9660.
///
/// Source : ECMA-119 §9.1 (Directory Record).
final class IsoEntry {
  /// Crée une entrée.
  const IsoEntry({
    required this.name,
    required this.lba,
    required this.size,
    required this.isDirectory,
  });

  /// Nom sans suffixe de version (`;1`).
  final String name;

  /// Premier secteur (Location of Extent).
  final int lba;

  /// Taille des données en octets (Data Length).
  final int size;

  /// `true` si l'entrée est un répertoire.
  final bool isDirectory;

  /// Offset absolu dans l'image, en octets.
  int get offset => lba * sectorSize;
}
