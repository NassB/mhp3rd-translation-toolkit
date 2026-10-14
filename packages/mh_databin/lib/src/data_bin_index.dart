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

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';

import 'data_bin_entry.dart';
import 'data_bin_toc.dart';
import 'data_cipher.dart';

/// Indices 0-based (TOC) des fichiers MHP3 JP stockés en clair.
///
/// Source : third_party/mhef/mhef/psp.py `_mhp3_jp_exceptions` (l.109), sans
/// explication dans les sources (voir docs/PROGRESS.md).
const Set<int> mhp3JpPlainIndices = {
  17, 18, 19, 20, //
  81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92,
};

/// Index des fichiers de `DATA.BIN`.
final class DataBinIndex {
  /// Crée un index à partir de ses [entries].
  DataBinIndex(List<DataBinEntry> entries)
      : entries = List<DataBinEntry>.unmodifiable(entries);

  /// Entrées dans l'ordre de la TOC.
  final List<DataBinEntry> entries;

  /// Entrée d'ID mhtools [id] (base 1).
  DataBinEntry byId(int id) {
    if (id < 1 || id > entries.length) {
      throw FormatError('unknown file id $id', fileId: id);
    }
    return entries[id - 1];
  }

  /// Construit l'index en lisant la TOC et le contenu de chaque fichier.
  static DataBinIndex build(
    DataBinReadAt readAt,
    int fileSize, {
    DataCipher cipher = const DataCipher(),
    Set<int> plainIndices = mhp3JpPlainIndices,
  }) {
    final toc = DataBinToc.parse(readAt, fileSize, cipher: cipher);
    final entries = <DataBinEntry>[];
    for (var i = 0; i < toc.fileCount; i++) {
      final lba = toc.sectorStarts[i];
      final slot = (toc.sectorStarts[i + 1] - lba) * sectorSize;
      final raw = readAt(lba * sectorSize, slot);
      final encrypted = !plainIndices.contains(i);
      final plain = encrypted ? cipher.decrypt(raw, lba) : raw;
      entries.add(
        DataBinEntry(
          id: i + 1,
          lba: lba,
          slotBytes: slot,
          sha1Plain: sha1.convert(plain).toString(),
          encrypted: encrypted,
        ),
      );
    }
    return DataBinIndex(entries);
  }
}
