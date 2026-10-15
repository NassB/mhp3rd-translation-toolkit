// Copyright (C) 2008-2011 Codestation (format et en-tête du patch)
//
// Format `MHP3RD_DATA.BIN` : écriture d'après third_party/mhtools/src/base/
// PatchBuilder.java (`create`), lecture d'après third_party/mhp3-translation-
// tools/patch-iso.py (`Patch.__init__`, `patch_iso`). Voir
// docs/FORMATS/patch.md et docs/DECISIONS/0001-licences.md.
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

import 'data_bin_index.dart';

/// Un bloc à écrire dans `DATA.BIN` (données déjà chiffrées).
final class PatchBlock {
  /// [offset] relatif au début de `DATA.BIN` ; [data] copié.
  PatchBlock({required this.offset, required Uint8List data})
      : data = Uint8List.fromList(data);

  /// Offset en octets depuis le début de `DATA.BIN` (`lba × 2048`).
  final int offset;

  /// Octets chiffrés, écrits tels quels.
  final Uint8List data;
}

/// Fichier de patch `MHP3RD_DATA.BIN`.
///
/// | Offset      | Taille | Type | Champ                                    |
/// |-------------|--------|------|------------------------------------------|
/// | 0x00        | 4      | u32  | count                                    |
/// | 0x04 + 8·i  | 4      | u32  | offset[i] (relatif à DATA.BIN)           |
/// | 0x08 + 8·i  | 4      | u32  | length[i]                                |
/// | 4 + 8·count | 0..15  | 0x00 | padding jusqu'à un multiple de 16        |
/// | ensuite     | Σ len  | u8[] | blocs concaténés, dans l'ordre de la table |
///
/// Source : PatchBuilder.java l.36-84 ; patch-iso.py l.17-30 (`headerlen =
/// N*8 + 4`, `headerpad = -headerlen % 16`). Little-endian.
final class PatchFile {
  /// Crée un patch à partir de [blocks] (ordre conservé).
  PatchFile(List<PatchBlock> blocks)
      : blocks = List<PatchBlock>.unmodifiable(blocks);

  /// Blocs dans l'ordre de la table.
  final List<PatchBlock> blocks;

  /// Sérialise le patch. Lève [PatchError] si une longueur n'est pas un
  /// multiple de 1024 (exigence de `patch-iso.py`, `assert numbytes == 0`).
  Uint8List serialize() {
    final w = ByteWriter();
    w.u32(blocks.length);
    for (final b in blocks) {
      if (b.data.length % 1024 != 0) {
        throw PatchError(
          'block length ${b.data.length} is not a multiple of 1024',
          offset: b.offset,
        );
      }
      w.u32(b.offset);
      w.u32(b.data.length);
    }
    w.padTo(16);
    for (final b in blocks) {
      w.bytes(b.data);
    }
    return w.toBytes();
  }

  /// Relit un patch. Les octets au-delà du dernier bloc (queue
  /// `install_tables` de mhtools, ignorée par `patch-iso.py`) sont ignorés.
  static PatchFile parse(Uint8List bytes) {
    final r = ByteReader(bytes);
    final count = r.u32();
    // Borne avant allocation : la table doit tenir dans le fichier.
    if (count > (bytes.length - 4) ~/ 8) {
      throw FormatError('patch count $count exceeds file size', offset: 0);
    }
    final table = <(int, int)>[];
    for (var i = 0; i < count; i++) {
      table.add((r.u32(), r.u32()));
    }
    final headerLen = 4 + 8 * count;
    r.seek(headerLen + (-headerLen % 16));
    final blocks = <PatchBlock>[];
    for (final (offset, length) in table) {
      blocks.add(PatchBlock(offset: offset, data: r.bytes(length)));
    }
    return PatchFile(blocks);
  }

  /// Vérifie le patch contre [index] (ARCHITECTURE.md §5.3) : chaque offset est
  /// exactement `lba × 2048` d'une entrée, `length % 2048 == 0`,
  /// `length <= slotBytes`, sans doublon ni chevauchement.
  /// Lève [PatchError] à la première violation.
  void validate(DataBinIndex index) {
    // Les slots vides (slotBytes = 0) partagent l'offset du suivant : ignorés.
    final byOffset = {
      for (final e in index.entries)
        if (e.slotBytes > 0) e.offset: e,
    };
    final seen = <int>{};
    for (final b in blocks) {
      final e = byOffset[b.offset];
      if (e == null) {
        throw PatchError('offset is not the start of a file', offset: b.offset);
      }
      if (b.data.length % sectorSize != 0) {
        throw PatchError(
          'block length ${b.data.length} is not sector-aligned',
          offset: b.offset,
          fileId: e.id,
        );
      }
      if (b.data.length > e.slotBytes) {
        throw PatchError(
          'block length ${b.data.length} exceeds slot ${e.slotBytes}',
          offset: b.offset,
          fileId: e.id,
        );
      }
      if (!seen.add(b.offset)) {
        throw PatchError('duplicate block', offset: b.offset, fileId: e.id);
      }
    }
    // Chevauchement : impossible si offsets distincts, exacts et <= slot, car
    // les slots de la TOC sont disjoints ; vérifié explicitement par sûreté.
    final sorted = [...blocks]..sort((a, b) => a.offset - b.offset);
    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      if (prev.offset + prev.data.length > sorted[i].offset) {
        throw PatchError('overlapping blocks', offset: sorted[i].offset);
      }
    }
  }
}
