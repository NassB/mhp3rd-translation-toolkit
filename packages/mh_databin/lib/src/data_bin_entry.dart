// Portage Dart de la lecture de TOC de third_party/mhef/mhef/psp.py
// (`DataCipher.decrypt_file`, l.216-248 ; exceptions `_mhp3_jp_exceptions`
// l.109), recoupée avec third_party/mhtools/src/crypt/Decrypter.java
// (`decrypt_index`, `decrypt_whole`). Voir docs/DECISIONS/0001-licences.md.
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.

import 'package:mh_binary/mh_binary.dart';

/// Fichier de `DATA.BIN` tel qu'indexé par la TOC.
///
/// `sizeBytes` (taille utile), `kind` et `label` sont hors périmètre de T7 et
/// seront ajoutés avec le catalogue (ARCHITECTURE.md §5.2).
final class DataBinEntry {
  /// Crée une entrée.
  const DataBinEntry({
    required this.id,
    required this.lba,
    required this.slotBytes,
    required this.sha1Plain,
    required this.encrypted,
  });

  /// Numéro mhtools, base 1 (= indice 0-based de la TOC + 1).
  final int id;

  /// Secteur de départ dans `DATA.BIN` ; LBA du chiffrement.
  final int lba;

  /// Espace alloué : `(start[i+1] - start[i]) × 2048`.
  final int slotBytes;

  /// SHA-1 hexadécimal du contenu en clair d'origine du slot entier.
  final String sha1Plain;

  /// `false` pour les fichiers stockés en clair (psp.py `_mhp3_jp_exceptions`).
  final bool encrypted;

  /// Offset en octets dans `DATA.BIN`.
  int get offset => lba * sectorSize;

  /// ID hexadécimal des chargeurs de mods (ID − 1, 4 chiffres majuscules).
  String get modId => (id - 1).toRadixString(16).toUpperCase().padLeft(4, '0');
}
