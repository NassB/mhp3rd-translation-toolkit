// Application d'un [PatchFile] sur une copie d'ISO.
//
// Sources : docs/ARCHITECTURE.md §9.3 (écriture à `databin_offset + offset`),
// §4.3 d'AGENTS.md (l'ISO source n'est jamais ouvert en écriture) ;
// comportement de third_party/mhp3-translation-tools/patch-iso.py
// (`patch_iso` : copie puis écriture des blocs à `iso_offset + offsets[n]`).

import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_iso/mh_iso.dart';

import 'data_bin_index.dart';
import 'patch_file.dart';

/// Copie [source] vers [outPath] puis y écrit les blocs de [patch].
///
/// La source n'est jamais ouverte en écriture ; [outPath] ne doit pas exister
/// (voir [IsoImage.cloneTo]). Le patch est validé contre [index] et contre la
/// taille de `DATA.BIN` avant toute création de fichier. Si l'écriture échoue,
/// le fichier partiel reste en place (l'erreur cite son chemin).
///
/// La copie n'est pas rouverte avec vérification : son MD5 ne correspond plus
/// au registre après patch.
Future<void> applyPatch(
  IsoImage source,
  PatchFile patch,
  DataBinIndex index, {
  required String outPath,
}) async {
  patch.validate(index);
  final dataBinSize = source.dataBin.size;
  for (final b in patch.blocks) {
    if (b.offset + b.data.length > dataBinSize) {
      throw PatchError(
        'block [${b.offset}, ${b.offset + b.data.length}) outside DATA.BIN '
        '(size $dataBinSize)',
        offset: b.offset,
      );
    }
  }

  final clone = await source.cloneTo(outPath);
  try {
    final base = clone.dataBin.offset;
    // FileMode.append : lecture/écriture sans troncature (ARCHITECTURE.md §9.3).
    final raf = await File(outPath).open(mode: FileMode.append);
    try {
      for (final b in patch.blocks) {
        await raf.setPosition(base + b.offset);
        await raf.writeFrom(b.data);
      }
    } on FileSystemException catch (e) {
      throw PatchError('write failed on partial output $outPath: ${e.message}');
    } finally {
      await raf.close();
    }
  } finally {
    clone.close();
  }
}
