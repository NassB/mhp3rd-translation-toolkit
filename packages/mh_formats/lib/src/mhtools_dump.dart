// Dossier d'échange mhtools (`filelist.txt` + `string_table_N.txt` +
// `enddata.bin`), en mémoire.
//
// Sources : third_party/mhtools/src/dec/ExtractPluginA.java (`extract`, écriture
// de filelist.txt), third_party/mhtools/src/enc/RebuildPluginA.java (`compile`).
// Copyright (C) 2008-2011 Codestation. Voir docs/DECISIONS/0001-licences.md.
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

import 'mhtools_text.dart';
import 'string_table_file.dart';

/// Contenu d'un dossier mhtools, sans accès disque.
final class MhtoolsDump {
  /// Voir les champs.
  MhtoolsDump({
    required this.fileListText,
    required List<String?> tableTexts,
    required Uint8List endData,
  })  : tableTexts = List.unmodifiable(tableTexts),
        endData = Uint8List.fromList(endData);

  /// `filelist.txt` : `<nom> <taille>`, `string_table_<j>.txt`…, `enddata.bin`.
  final String fileListText;

  /// Contenu de `string_table_<j>.txt` ; `null` = table nulle (pas de fichier).
  final List<String?> tableTexts;

  /// Contenu de `enddata.bin`.
  final Uint8List endData;
}

/// Nom du fichier texte de la table [j].
String mhtoolsTableFileName(int j) => 'string_table_$j.txt';

/// Exporte [file] au format mhtools. [name] et [size] alimentent la
/// première ligne de `filelist.txt` (nom du `.bin` et taille en octets).
MhtoolsDump exportMhtoolsDump(
  StringTableFile file, {
  required String name,
  required int size,
  int? fileId,
}) {
  final list = StringBuffer('$name $size\n');
  final texts = <String?>[];
  for (var j = 0; j < file.tables.length; j++) {
    list.write('${mhtoolsTableFileName(j)}\n');
    final t = file.tables[j];
    texts.add(
      t == null ? null : joinLines(exportTableLines(t, fileId: fileId)),
    );
  }
  list.write('enddata.bin\n');
  return MhtoolsDump(
    fileListText: list.toString(),
    tableTexts: texts,
    endData: file.endData,
  );
}

/// Applique [dump] sur [original] : offsets, alias et en-tête d'origine
/// conservés, textes et `endData` remplacés. Le nombre de tables et leur
/// nullité doivent correspondre à l'original.
StringTableFile importMhtoolsDump(
  StringTableFile original,
  MhtoolsDump dump, {
  int? fileId,
}) {
  FormatError fail(String msg) => FormatError(msg, offset: 0, fileId: fileId);
  if (dump.tableTexts.length != original.tables.length) {
    throw fail(
      'expected ${original.tables.length} tables, '
      'got ${dump.tableTexts.length}',
    );
  }
  final tables = <StringTable?>[];
  for (var j = 0; j < original.tables.length; j++) {
    final t = original.tables[j];
    final text = dump.tableTexts[j];
    if (t == null || text == null) {
      if (t != null || text != null) {
        throw fail('table $j: null/non-null mismatch with the original');
      }
      tables.add(null);
      continue;
    }
    try {
      tables.add(applyTableLines(t, splitLines(text), fileId: fileId));
    } on FormatError catch (e) {
      throw FormatError('table $j: ${e.message}', offset: 0, fileId: fileId);
    }
  }
  return StringTableFile(
    unknownHeader: original.unknownHeader,
    tables: tables,
    endData: dump.endData,
  );
}
