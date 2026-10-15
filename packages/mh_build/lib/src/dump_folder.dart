// Import et export de dossiers au format mhtools pour un fichier du projet
// (docs/ARCHITECTURE.md §7.5), partagés par la CLI et le studio.
//
// Source du format : docs/FORMATS/string_table_a.md (`filelist.txt`,
// `string_table_<j>.txt`, `enddata.bin`) ; un dossier = un fichier.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'build_patch.dart';
import 'project.dart';

/// Lit un dossier de dump mhtools pour un fichier de [tableCount] tables.
/// Une table sans `string_table_<j>.txt` est une table nulle. Lève
/// [FileSystemException] si le dossier n'existe pas, [FormatException] si un
/// texte n'est pas de l'UTF-8.
MhtoolsDump readMhtoolsDumpFolder(String folder, int tableCount) {
  if (!Directory(folder).existsSync()) {
    throw FileSystemException('dump folder not found', folder);
  }
  String? read(String name) {
    final f = File('$folder/$name');
    return f.existsSync() ? utf8.decode(f.readAsBytesSync()) : null;
  }

  final endData = File('$folder/enddata.bin');
  return MhtoolsDump(
    fileListText: read('filelist.txt') ?? '',
    tableTexts: [
      for (var j = 0; j < tableCount; j++) read(mhtoolsTableFileName(j)),
    ],
    endData: endData.existsSync() ? endData.readAsBytesSync() : Uint8List(0),
  );
}

/// Lit et décode l'original du fichier [fileId] dans l'ISO du projet, sans
/// construire l'index complet de `DATA.BIN` (lecture seule d'un seul slot).
///
/// L'ISO n'est pas revérifiée par MD5 ici (lecture seule) : l'appelant
/// compare les textes à la base. [config] : registre des versions.
Future<({StringTableFile file, int size})> readOriginalFile(
  Project project,
  TdbDatabase db,
  int fileId, {
  required String config,
}) async {
  final row = await gameFileById(db, fileId);
  if (row == null) throw TdbError('file not imported', fileId: fileId);
  final registry = GameVersionRegistry.fromFile(config);
  final version =
      registry.versions.where((v) => v.id == project.versionId).firstOrNull;
  if (version == null) {
    throw IsoError('unknown game version ${project.versionId}');
  }
  final raf = File(project.isoPath).openSync();
  try {
    final start = version.databinIsoOffset + row.lba * sectorSize;
    if (start + row.slotBytes > raf.lengthSync()) {
      throw IsoError(
        'slot of file $fileId lies beyond the ISO',
        fileId: fileId,
      );
    }
    raf.setPositionSync(start);
    final raw = Uint8List(row.slotBytes);
    var got = 0;
    while (got < raw.length) {
      final n = raf.readIntoSync(raw, got);
      if (n == 0) throw IsoError('short read of file $fileId', fileId: fileId);
      got += n;
    }
    // Les exceptions en clair de DATA.BIN sont indexées depuis 0.
    final plain = mhp3JpPlainIndices.contains(fileId - 1)
        ? raw
        : const DataCipher().decrypt(raw, row.lba);
    return (
      file: decodeStringTableA(plain, fileId: fileId),
      size: plain.length
    );
  } finally {
    raf.closeSync();
  }
}

/// Applique le dossier de dump [folder] (traduit) au fichier [fileId] :
/// `importMhtoolsTranslations` sur l'original relu dans l'ISO. Retourne le
/// nombre de traductions créées ou modifiées.
Future<int> importDumpFolder({
  required TdbDatabase db,
  required Project project,
  required String config,
  required int fileId,
  required String folder,
  String status = 'draft',
}) async {
  final original = (await readOriginalFile(
    project,
    db,
    fileId,
    config: config,
  ))
      .file;
  final dump = readMhtoolsDumpFolder(folder, original.tables.length);
  return importMhtoolsTranslations(
    db,
    fileId: fileId,
    original: original,
    dump: dump,
    locale: project.locale,
    status: status,
  );
}

/// Écrit dans [folder] le dump mhtools du fichier [fileId] avec les
/// traductions de statut [minStatus] ou plus (le reste garde la source). Le
/// dossier ne doit pas déjà contenir un dump. Retourne le nombre de tables
/// écrites.
Future<int> exportDumpFolder({
  required TdbDatabase db,
  required Project project,
  required String config,
  required int fileId,
  required String folder,
  String minStatus = 'draft',
}) async {
  if (File('$folder/filelist.txt').existsSync()) {
    throw TdbError('destination already contains a dump', fileId: fileId);
  }
  final (:file, :size) = await readOriginalFile(
    project,
    db,
    fileId,
    config: config,
  );
  final all = await eligibleTranslations(
    db,
    locale: project.locale,
    minStatus: minStatus,
  );
  final translated = applyTranslations(
    file,
    [
      for (final t in all)
        if (t.fileId == fileId) t,
    ],
    fileId,
    keepEndData: true,
  );
  final dump = exportMhtoolsDump(
    translated,
    name: '${fileId.toString().padLeft(4, '0')}.bin',
    size: size,
    fileId: fileId,
  );
  Directory(folder).createSync(recursive: true);
  File('$folder/filelist.txt').writeAsStringSync(dump.fileListText);
  var written = 0;
  for (var j = 0; j < dump.tableTexts.length; j++) {
    final text = dump.tableTexts[j];
    if (text == null) continue;
    File('$folder/${mhtoolsTableFileName(j)}').writeAsStringSync(text);
    written++;
  }
  File('$folder/enddata.bin').writeAsBytesSync(dump.endData);
  return written;
}
