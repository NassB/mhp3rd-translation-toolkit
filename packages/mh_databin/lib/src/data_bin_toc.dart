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

import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

import 'data_cipher.dart';

/// Lecture brute de `length` octets à `offset` dans `DATA.BIN`.
typedef DataBinReadAt = Uint8List Function(int offset, int length);

/// Table des matières de `DATA.BIN` (déchiffrée).
///
/// | Offset      | Taille | Type  | Champ                                      |
/// |-------------|--------|-------|--------------------------------------------|
/// | 0x00        | 4 × N  | u32   | `starts[i]` : début du fichier i, en secteurs |
/// | 4 × N       | 4      | u32   | sentinelle = `fileSize / 2048`             |
///
/// La TOC est chiffrée avec `lba = 0`. Sa taille est `starts[0] × 2048`
/// (le premier fichier suit immédiatement la TOC). Le nombre de fichiers N est
/// l'indice de la première entrée égale à la taille totale en secteurs.
///
/// Source : third_party/mhef/mhef/psp.py `DataCipher.decrypt_file` l.216-248.
final class DataBinToc {
  /// Crée une TOC à partir de [sectorStarts] (sentinelle incluse).
  DataBinToc._(this.sectorStarts);

  /// Début de chaque fichier en secteurs de 2048 octets, sentinelle finale
  /// (`fileSize / 2048`) incluse : `fileCount + 1` valeurs.
  final List<int> sectorStarts;

  /// Nombre de fichiers.
  int get fileCount => sectorStarts.length - 1;

  /// Lit et déchiffre la TOC d'un `DATA.BIN` de [fileSize] octets.
  static DataBinToc parse(
    DataBinReadAt readAt,
    int fileSize, {
    DataCipher cipher = const DataCipher(),
  }) {
    if (fileSize <= 0 || fileSize % sectorSize != 0) {
      throw FormatError(
        'DATA.BIN size $fileSize is not a positive multiple of $sectorSize',
        offset: 0,
      );
    }
    final totalSectors = fileSize ~/ sectorSize;

    // Taille de la TOC : premier u32 déchiffré × 2048 (psp.py l.230-233).
    final head = cipher.decrypt(readAt(0, 4), 0);
    final tocSectors = ByteReader(head).u32();
    if (tocSectors == 0 || tocSectors >= totalSectors) {
      throw FormatError(
        'invalid TOC size: $tocSectors sectors (DATA.BIN has $totalSectors)',
        offset: 0,
      );
    }
    final tocBytes = tocSectors * sectorSize;
    final reader = ByteReader(cipher.decrypt(readAt(0, tocBytes), 0));

    final starts = <int>[];
    var previous = -1;
    while (reader.remaining >= 4) {
      final offset = reader.position;
      final v = reader.u32();
      // Non décroissant : deux entrées égales = slot vide (observé sur
      // DATA.BIN réel ; psp.py l.238-243 ne l'interdit pas, taille 0).
      if (v < previous) {
        throw FormatError(
          'TOC decreasing: $v after $previous',
          offset: offset,
        );
      }
      if (v > totalSectors) {
        throw FormatError(
          'TOC entry $v beyond DATA.BIN end ($totalSectors sectors)',
          offset: offset,
        );
      }
      starts.add(v);
      if (v == totalSectors) {
        if (starts.length < 2) {
          throw FormatError('TOC contains no file', offset: offset);
        }
        if (starts.first != tocSectors) {
          throw FormatError(
            'first file starts at sector ${starts.first}, '
            'expected $tocSectors (end of TOC)',
            offset: 0,
          );
        }
        return DataBinToc._(List<int>.unmodifiable(starts));
      }
      previous = v;
    }
    throw const FormatError(
      'TOC sentinel (DATA.BIN size in sectors) not found',
      offset: 0,
    );
  }
}
