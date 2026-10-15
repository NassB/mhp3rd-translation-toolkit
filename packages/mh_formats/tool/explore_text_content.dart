// ignore_for_file: type=lint
// Exploration: UTF-8, octets de contrôle, motifs, caractères hors kana/kanji.
// Usage: dart run packages/mh_formats/tool/explore_text_content.dart local/MHP3.iso
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';

String hx(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

/// Retourne l'index du premier octet invalide, ou -1.
int firstBad(Uint8List b) {
  var i = 0;
  while (i < b.length) {
    final c = b[i];
    int n;
    if (c < 0x80) {
      n = 1;
    } else if (c >= 0xC2 && c <= 0xDF) {
      n = 2;
    } else if (c >= 0xE0 && c <= 0xEF) {
      n = 3;
    } else if (c >= 0xF0 && c <= 0xF4) {
      n = 4;
    } else {
      return i;
    }
    if (i + n > b.length) return i;
    for (var k = 1; k < n; k++) {
      if (b[i + k] & 0xC0 != 0x80) return i;
    }
    i += n;
  }
  return -1;
}

Future<void> main(List<String> a) async {
  final iso = a[0];
  final reg = GameVersionRegistry.fromFile('config/game_versions.yaml');
  final img = await FileIsoImage.open(iso, reg);
  final raf = File(iso).openSync();
  final base = img.dataBin.offset;
  Uint8List readAt(int o, int l) {
    raf.setPositionSync(base + o);
    final out = Uint8List(l);
    var g = 0;
    while (g < l) {
      final n = raf.readIntoSync(out, g);
      if (n == 0) throw StateError('eof');
      g += n;
    }
    return out;
  }

  const c = DataCipher();
  final idx = DataBinIndex.build(readAt, img.dataBin.size);
  final out = StringBuffer();

  var files = 0, slots = 0, aliasSlots = 0, emptySlots = 0;
  final badFiles = <int, int>{}; // id -> nb slots invalides
  final badBytes = <int, int>{}; // octet fautif -> compte
  final badCtx = <String, int>{};
  final ctlByte = <int, int>{};
  final ctlByteFiles = <int, Set<int>>{};
  final ctlPat = <String, int>{};
  final ctlPatFiles = <String, Set<int>>{};
  final lit = <String, int>{};
  final litFiles = <String, Set<int>>{};
  final chars = <int, int>{};
  final charFiles = <int, Set<int>>{};
  var del7f = 0;
  final lits = ['<NEWLINE>', '<EMPTY STRING>'];
  var nonAsciiSlots = 0, asciiSlots = 0;
  final naIds = <int>{};
  final tagPat = <String, int>{};
  final asciiSym = <int, int>{};
  final alnum = RegExp('[0-9A-Za-z]');
  final tagRe = RegExp(r'[<{\[][^>}\]]{0,12}[>}\]]');

  for (final e in idx.entries) {
    if (e.slotBytes == 0) continue;
    final raw = readAt(e.offset, e.slotBytes);
    final plain = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final StringTableFile f;
    try {
      f = decodeStringTableA(plain, fileId: e.id);
    } on FormatError {
      continue;
    }
    files++;
    for (final t in f.tables) {
      if (t == null) continue;
      for (final s in t.slots) {
        if (s.aliasOf != null) {
          aliasSlots++;
          continue;
        }
        slots++;
        final b = s.raw;
        if (b.isEmpty) emptySlots++;
        final bad = firstBad(b);
        if (bad >= 0) {
          badFiles[e.id] = (badFiles[e.id] ?? 0) + 1;
          badBytes[b[bad]] = (badBytes[b[bad]] ?? 0) + 1;
          final k = hx(b.sublist(bad, bad + 3 > b.length ? b.length : bad + 3));
          badCtx[k] = (badCtx[k] ?? 0) + 1;
        }
        for (var i = 0; i < b.length; i++) {
          final x = b[i];
          if ((x < 0x20 && x != 0x0A) || x == 0x7F) {
            ctlByte[x] = (ctlByte[x] ?? 0) + 1;
            (ctlByteFiles[x] ??= {}).add(e.id);
            final end = i + 4 > b.length ? b.length : i + 4;
            final p = hx(b.sublist(i, end));
            ctlPat[p] = (ctlPat[p] ?? 0) + 1;
            (ctlPatFiles[p] ??= {}).add(e.id);
          }
        }
        if (bad < 0) {
          final s2 = utf8.decode(b);
          if (b.any((x) => x >= 0x80)) {
            nonAsciiSlots++;
            naIds.add(e.id);
          } else if (b.isNotEmpty) {
            asciiSlots++;
          }
          for (final m in tagRe.allMatches(s2)) {
            tagPat[m.group(0)!] = (tagPat[m.group(0)!] ?? 0) + 1;
          }
          for (final x in b) {
            if (x >= 0x21 &&
                x < 0x7F &&
                !alnum.hasMatch(String.fromCharCode(x))) {
              asciiSym[x] = (asciiSym[x] ?? 0) + 1;
            }
          }
          for (final l in lits) {
            if (s2.contains(l)) {
              lit[l] = (lit[l] ?? 0) + 1;
              (litFiles[l] ??= {}).add(e.id);
            }
          }
          for (final r in s2.runes) {
            if (r < 0x80) continue;
            final kana = r >= 0x3041 && r <= 0x30FF;
            final kanji =
                (r >= 0x4E00 && r <= 0x9FFF) || (r >= 0x3400 && r <= 0x4DBF);
            if (kana || kanji) continue;
            chars[r] = (chars[r] ?? 0) + 1;
            (charFiles[r] ??= {}).add(e.id);
          }
        }
      }
    }
  }
  if (del7f > 0) out.writeln('del7f=$del7f');

  String cls(int r) {
    if (r >= 0xE000 && r <= 0xF8FF) return 'PUA';
    if (r >= 0x3000 && r <= 0x303F) return 'CJKpunct';
    if (r >= 0xFF00 && r <= 0xFFEF) return 'Fullwidth';
    if (r >= 0x2000 && r <= 0x2BFF) return 'Symbols/Arrows/Geom';
    if (r >= 0x80 && r <= 0x24F) return 'Latin1/Ext';
    if (r >= 0x370 && r <= 0x52F) return 'Greek/Cyrillic';
    if (r >= 0x1F000) return 'Emoji/Supp';
    return 'Other';
  }

  out.writeln(
      'files=$files slots(unique)=$slots aliasSlots=$aliasSlots empty=$emptySlots');
  out.writeln(
      '\n[1] invalid UTF-8 slots: ${badFiles.values.fold(0, (a, b) => a + b)} in ${badFiles.length} files');
  out.writeln(
      'files: ${badFiles.entries.take(60).map((e) => '${e.key}:${e.value}').join(' ')}');
  out.writeln(
      'first-bad byte histogram: ${badBytes.entries.map((e) => '${e.key.toRadixString(16)}=${e.value}').join(' ')}');
  final bc = badCtx.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in bc.take(25)) out.writeln('  badctx ${e.key} x${e.value}');

  out.writeln('\n[2] control bytes (byte: count / files)');
  for (final k in (ctlByte.keys.toList()..sort())) {
    out.writeln(
        '  0x${k.toRadixString(16).padLeft(2, '0')}: ${ctlByte[k]} / ${ctlByteFiles[k]!.length}');
  }
  final cp = ctlPat.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  out.writeln('top patterns (ctl + 3 next bytes):');
  for (final e in cp.take(60))
    out.writeln('  ${e.key}: ${e.value} / ${ctlPatFiles[e.key]!.length}');
  out.writeln('distinct patterns: ${ctlPat.length}');

  out.writeln('\n[3] literals');
  for (final l in lits) {
    out.writeln(
        '  $l: ${lit[l] ?? 0} slots / ${litFiles[l]?.length ?? 0} files');
  }

  out.writeln('\n[4] non-ASCII hors kana/kanji: distinct=${chars.length}');
  final byCls = <String, int>{};
  for (final e in chars.entries) {
    byCls[cls(e.key)] = (byCls[cls(e.key)] ?? 0) + e.value;
  }
  out.writeln('par classe: $byCls');
  final cc = chars.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in cc.take(80)) {
    out.writeln(
        '  U+${e.key.toRadixString(16).toUpperCase().padLeft(4, '0')} [${cls(e.key)}] ${e.value} / ${charFiles[e.key]!.length}');
  }
  out.writeln(
      'PUA codepoints: ${(chars.keys.where((r) => r >= 0xE000 && r <= 0xF8FF).toList()..sort()).map((r) => r.toRadixString(16)).join(' ')}');

  out.writeln(
      '\n[5] nonAsciiSlots=$nonAsciiSlots asciiSlots=$asciiSlots filesWithNonAscii=${naIds.length}');
  final ids = naIds.toList()..sort();
  out.writeln('ids non-ASCII: ${ids.take(40).join(' ')}');
  final tp = tagPat.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  out.writeln(
      'bracket patterns distinct=${tagPat.length}: ${tp.take(15).map((e) => '${e.key}x${e.value}').join(' ')}');
  out.writeln(
      'ascii symbols: ${asciiSym.entries.map((e) => '${String.fromCharCode(e.key)}=${e.value}').join(' ')}');
  Directory('local/explore').createSync(recursive: true);
  File('local/explore/text_content.txt').writeAsStringSync(out.toString());
  print(out);
}
