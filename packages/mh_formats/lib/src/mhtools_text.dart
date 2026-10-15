// Format texte d'échange de mhtools (une chaîne par ligne).
//
// Sources : third_party/mhtools/src/dec/ExtractPluginA.java (`extract`,
// marqueurs `<NEWLINE>` / `<EMPTY STRING>`), third_party/mhtools/src/enc/
// RebuildPluginA.java (`createStringTable`), HelperEnc.java (`readString`,
// `checkUnicodeBOM`). Copyright (C) 2008-2011 Codestation.
// Voir docs/DECISIONS/0001-licences.md.
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

import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

import 'string_table_file.dart';

const String _newlineMarker = '<NEWLINE>';
const String _emptyMarker = '<EMPTY STRING>';

/// Exporte les slots d'une [table] en lignes mhtools (alias dupliqués).
///
/// Lève [FormatError] si une chaîne n'est pas de l'UTF-8 valide, contient un
/// marqueur littéral ou se termine par `\r` (non représentable sans perte).
List<String> exportTableLines(StringTable table, {int? fileId}) {
  final lines = <String>[];
  const decoder = Utf8Decoder();
  for (final s in table.slots) {
    FormatError fail(String msg) =>
        FormatError('slot ${s.index}: $msg', offset: 0, fileId: fileId);
    if (s.raw.isEmpty) {
      lines.add(_emptyMarker);
      continue;
    }
    final String text;
    try {
      text = decoder.convert(s.raw);
    } on FormatException {
      throw fail('not valid UTF-8');
    }
    if (text.contains(_newlineMarker) || text.contains(_emptyMarker)) {
      throw fail('contains a literal mhtools marker');
    }
    if (text.endsWith('\r')) throw fail('ends with a lone CR');
    lines.add(text.replaceAll('\n', _newlineMarker));
  }
  return lines;
}

/// Joint des lignes en fichier texte (`\n`, terminé par un saut de ligne).
String joinLines(List<String> lines) =>
    lines.isEmpty ? '' : '${lines.join('\n')}\n';

/// Découpe un fichier texte mhtools en lignes.
///
/// Tolère BOM UTF-8, `\r\n` et l'absence de saut de ligne final (mhtools
/// perd alors la dernière ligne ; on la conserve).
List<String> splitLines(String text) {
  var t = text;
  if (t.startsWith('﻿')) t = t.substring(1);
  if (t.isEmpty) return const [];
  final lines = t.split('\n');
  if (lines.last.isEmpty) lines.removeLast();
  return [
    for (final l in lines) l.endsWith('\r') ? l.substring(0, l.length - 1) : l,
  ];
}

/// Applique [lines] sur [table] : mêmes offsets d'origine et mêmes alias,
/// textes remplacés. Les alias doivent répéter le texte de leur cible.
StringTable applyTableLines(
  StringTable table,
  List<String> lines, {
  int? fileId,
}) {
  FormatError fail(String msg) => FormatError(msg, offset: 0, fileId: fileId);
  if (lines.length != table.slots.length) {
    throw fail('expected ${table.slots.length} lines, got ${lines.length}');
  }
  final slots = <StringSlot>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final Uint8List raw;
    if (line == _emptyMarker || line.isEmpty) {
      raw = Uint8List(0);
    } else {
      if (line.contains(_emptyMarker)) {
        throw fail('line ${i + 1}: $_emptyMarker mixed with text');
      }
      final text = line.replaceAll(_newlineMarker, '\n');
      if (text.contains('\u0000')) throw fail('line ${i + 1}: contains NUL');
      raw = Uint8List.fromList(utf8.encode(text));
    }
    final alias = table.slots[i].aliasOf;
    if (alias != null && !_sameBytes(raw, slots[alias].raw)) {
      throw fail('line ${i + 1}: alias of slot $alias must repeat its text');
    }
    slots.add(StringSlot(index: i, raw: raw, aliasOf: alias));
  }
  return StringTable(originalOffsets: table.originalOffsets, slots: slots);
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
