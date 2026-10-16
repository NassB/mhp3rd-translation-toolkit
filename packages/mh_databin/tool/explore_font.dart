// ignore_for_file: type=lint
// Exploration (lecture seule) : où est la police ? Conteneurs TMH / GIM de
// DATA.BIN, chaînes et tables de EBOOT.BIN. Sortie détaillée dans
// local/explore/font_*.txt, PNG dans local/explore/font_candidates/.
// Format GIM : third_party/mhtools/src/img/Gim.java ; conteneur TMH :
// third_party/mhtools/src/dec/ExtractPluginD.java.
//
// Rejouer : dart run packages/mh_databin/tool/explore_font.dart local/MHP3.iso
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';

final class Gim {
  Gim(this.offset, this.total, this.dataType, this.w, this.h, this.imgOff,
      this.imgLen, this.palType, this.palCount, this.palOff);
  final int offset,
      total,
      dataType,
      w,
      h,
      imgOff,
      imgLen,
      palType,
      palCount,
      palOff;
}

const tmhMagic = [0x2E, 0x54, 0x4D, 0x48, 0x30, 0x2E, 0x31, 0x34];
const migMagic = [0x4D, 0x49, 0x47, 0x2E]; // "MIG."

bool startsWith(Uint8List d, List<int> m, [int at = 0]) {
  if (d.length < at + m.length) return false;
  for (var i = 0; i < m.length; i++) {
    if (d[at + i] != m[i]) return false;
  }
  return true;
}

/// Parse un GIM "mhtools" (Gim.load) à [pos]. null si incohérent.
Gim? parseGim(Uint8List d, int pos) {
  if (pos + 32 > d.length) return null;
  final bd = ByteData.sublistView(d);
  final size = bd.getUint32(pos, Endian.little);
  final dataSize = bd.getUint32(pos + 16, Endian.little);
  final dataType = bd.getUint32(pos + 24, Endian.little);
  final w = bd.getUint16(pos + 28, Endian.little);
  final h = bd.getUint16(pos + 30, Endian.little);
  if (size < 32 || pos + size > d.length || dataSize < 16) return null;
  if (dataType > 8) return null;
  final imgOff = pos + 32;
  final imgLen = dataSize - 16;
  if (imgOff + imgLen > d.length) return null;
  var palType = -1, palCount = 0, palOff = -1;
  if (dataType != 8) {
    final p = imgOff + imgLen;
    if (p + 16 > d.length) return null;
    palType = bd.getUint32(p + 8, Endian.little);
    palCount = bd.getUint32(p + 12, Endian.little);
    palOff = p + 16;
  }
  return Gim(
      pos, size, dataType, w, h, imgOff, imgLen, palType, palCount, palOff);
}

/// Décode la palette [n] en ARGB (Gim.getRGBarray, 16 bits en little-endian).
List<int> palette(Uint8List d, Gim g, int n) {
  final maxColors = g.dataType == 4 ? 16 : 256;
  final cs = g.palType == 3 ? 4 : 2;
  final start = g.palOff + n * maxColors * cs;
  final out = <int>[];
  final bd = ByteData.sublistView(d);
  for (var i = 0; i < maxColors; i++) {
    final o = start + i * cs;
    if (o + cs > d.length) {
      out.add(0);
      continue;
    }
    if (cs == 4) {
      out.add((d[o + 3] << 24) | (d[o] << 16) | (d[o + 1] << 8) | d[o + 2]);
    } else {
      final v = bd.getUint16(o, Endian.little);
      int e5(int x) => (x << 3) | (x >> 2);
      if (g.palType == 0) {
        final r = v & 31, gg = (v >> 5) & 63, b = v >> 11;
        out.add(0xFF000000 |
            (e5(r) << 16) |
            (((gg << 2) | (gg >> 4)) << 8) |
            e5(b));
      } else if (g.palType == 2) {
        int e4(int x) => x * 17;
        out.add((e4(v >> 12) << 24) |
            (e4(v & 15) << 16) |
            (e4((v >> 4) & 15) << 8) |
            e4((v >> 8) & 15));
      } else {
        final r = v & 31, gg = (v >> 5) & 31, b = (v >> 10) & 31;
        out.add(((v >> 15) == 0 ? 0 : 0xFF000000) |
            (e5(r) << 16) |
            (e5(gg) << 8) |
            e5(b));
      }
    }
  }
  return out;
}

/// Indices de pixels (Gim.getRGBarray : blocs 16x8 octets, 4 bits = 2 px).
Uint8List? indices(Uint8List d, Gim g) {
  if (g.dataType != 4 && g.dataType != 5) return null;
  final m = g.dataType == 4 ? 2 : 1;
  final bw = 16 * m;
  if (g.w % bw != 0 || g.h % 8 != 0) return null;
  final need = g.dataType == 4 ? g.w * g.h ~/ 2 : g.w * g.h;
  if (g.imgLen < need) return null;
  final out = Uint8List(g.w * g.h);
  var c = 0;
  for (var sy = 0; sy < g.h ~/ 8; sy++) {
    for (var sx = 0; sx < g.w ~/ bw; sx++) {
      for (var y = 0; y < 8; y++) {
        for (var x = 0; x < bw; x++) {
          final off = (sy * 8 + y) * g.w + sx * bw + x;
          var pos = d[g.imgOff + c];
          if (g.dataType == 4) {
            if (x % 2 == 0) {
              pos &= 15;
            } else {
              pos >>= 4;
              c++;
            }
          } else {
            c++;
          }
          out[off] = pos;
        }
      }
    }
  }
  return out;
}

// ---- PNG minimal (RGBA 8 bits) ----
final _crcTable = () {
  final t = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    t[n] = c;
  }
  return t;
}();
int crc32(List<int> b) {
  var c = 0xFFFFFFFF;
  for (final x in b) {
    c = _crcTable[(c ^ x) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List png(int w, int h, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    raw.add(Uint8List.sublistView(rgba, y * w * 4, (y + 1) * w * 4));
  }
  final z = ZLibEncoder().convert(raw.toBytes());
  final out = BytesBuilder();
  void chunk(String t, List<int> data) {
    final bd = ByteData(4)..setUint32(0, data.length);
    out.add(bd.buffer.asUint8List());
    final body = [...t.codeUnits, ...data];
    out.add(body);
    final c = ByteData(4)..setUint32(0, crc32(body));
    out.add(c.buffer.asUint8List());
  }

  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ih = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  chunk('IHDR', ih.buffer.asUint8List());
  chunk('IDAT', z);
  chunk('IEND', []);
  return out.toBytes();
}

Future<void> main(List<String> a) async {
  final isoPath = a[0];
  final reg = GameVersionRegistry.fromFile('config/game_versions.yaml');
  final img = await FileIsoImage.open(isoPath, reg);
  final raf = File(isoPath).openSync();
  Uint8List readIso(int o, int l) {
    raf.setPositionSync(o);
    final out = Uint8List(l);
    var g = 0;
    while (g < l) {
      final n = raf.readIntoSync(out, g);
      if (n == 0) throw StateError('eof');
      g += n;
    }
    return out;
  }

  final base = img.dataBin.offset;
  Uint8List readAt(int o, int l) => readIso(base + o, l);
  const c = DataCipher();
  final idx = DataBinIndex.build(readAt, img.dataBin.size);
  final log = StringBuffer();
  final hist = <String, int>{};
  final cands = <Map<String, Object>>[];
  var tmhFiles = 0, migFiles = 0, gimTotal = 0, pgf = 0, nestedMig = 0;
  final nested = <int, int>{};

  for (final e in idx.entries) {
    if (e.slotBytes == 0) continue;
    final raw = readAt(e.offset, e.slotBytes);
    final d = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final isTmh = startsWith(d, tmhMagic);
    final isMig = startsWith(d, migMagic);
    if (startsWith(d, [0x50, 0x47, 0x46, 0x30])) pgf++;
    if (!isTmh && !isMig) {
      var n = 0;
      for (var i = 0; i + 11 <= d.length; i++) {
        if (d[i] == 0x4D &&
            d[i + 1] == 0x49 &&
            d[i + 2] == 0x47 &&
            d[i + 3] == 0x2E &&
            d[i + 4] == 0x30 &&
            d[i + 5] == 0x30) {
          n++;
        }
      }
      if (n > 0) {
        nested[e.id] = n;
        nestedMig += n;
      }
      continue;
    }
    final gims = <Gim>[];
    if (isTmh) {
      tmhFiles++;
      final cnt = ByteData.sublistView(d).getUint32(8, Endian.little);
      var pos = 16;
      for (var i = 0; i < cnt; i++) {
        final g = parseGim(d, pos);
        if (g == null) {
          log.writeln('id=${e.id} gim#$i parse échec à $pos');
          break;
        }
        gims.add(g);
        pos += g.total;
      }
      log.writeln(
          'id=${e.id} TMH size=${d.length} count=$cnt parsed=${gims.length} end=${pos}');
    } else {
      migFiles++;
      log.writeln(
          'id=${e.id} MIG. size=${d.length} head=${d.sublist(0, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    }
    for (var i = 0; i < gims.length; i++) {
      final g = gims[i];
      gimTotal++;
      final key = 'type${g.dataType} ${g.w}x${g.h}';
      hist[key] = (hist[key] ?? 0) + 1;
      log.writeln(
          '  id=${e.id} gim#$i type=${g.dataType} ${g.w}x${g.h} palType=${g.palType} palCount=${g.palCount}');
      final ix = indices(d, g);
      if (ix == null) continue;
      // fréquences d'indices, encre = pixels != indice le plus fréquent
      final freq = List<int>.filled(256, 0);
      for (final v in ix) {
        freq[v]++;
      }
      var bg = 0;
      for (var k = 1; k < 256; k++) {
        if (freq[k] > freq[bg]) bg = k;
      }
      final ink = 1 - freq[bg] / ix.length;
      final used = freq.where((x) => x > 0).length;
      // cellules 16x16 non vides
      var cells = 0, nonEmpty = 0;
      for (var cy = 0; cy + 16 <= g.h; cy += 16) {
        for (var cx = 0; cx + 16 <= g.w; cx += 16) {
          cells++;
          var any = false;
          for (var y = 0; y < 16 && !any; y++) {
            for (var x = 0; x < 16; x++) {
              if (ix[(cy + y) * g.w + cx + x] != bg) {
                any = true;
                break;
              }
            }
          }
          if (any) nonEmpty++;
        }
      }
      final sizeOk = [
        [256, 256],
        [512, 256],
        [512, 512],
        [256, 128],
        [128, 128],
        [128, 256],
        [1024, 512],
        [1024, 1024]
      ].any((s) => s[0] == g.w && s[1] == g.h);
      final fill = cells == 0 ? 0.0 : nonEmpty / cells;
      // score : encre 4-40 %, peu d'indices utilisés, taille compatible, cellules partiellement remplies
      var score = 0.0;
      if (ink > 0.03 && ink < 0.45) score += 1;
      if (used <= 16) score += 1;
      if (sizeOk) score += 1;
      if (fill > 0.3 && fill < 1.0) score += 1;
      cands.add({
        'id': e.id,
        'gim': i,
        'w': g.w,
        'h': g.h,
        'type': g.dataType,
        'ink': ink,
        'used': used,
        'fill': fill,
        'score': score,
        'bg': bg,
        'pal': palette(d, g, 0),
        'ix': ix,
      });
    }
  }

  log.writeln('---');
  log.writeln('TMH=$tmhFiles MIG=$migFiles GIM total=$gimTotal PGF0=$pgf');
  log.writeln(
      'MIG.00 imbriqués hors TMH/MIG: fichiers=${nested.length} occurrences=$nestedMig');
  log.writeln(
      'imbriqués (id:n) ${nested.entries.take(40).map((e) => '${e.key}:${e.value}').join(' ')}');
  final hk = hist.keys.toList()..sort((x, y) => hist[y]!.compareTo(hist[x]!));
  for (final k in hk) {
    log.writeln('hist $k : ${hist[k]}');
  }

  // PNG des meilleurs candidats (dédupliqués par contenu d'indices)
  cands.sort((x, y) {
    final s = (y['score'] as double).compareTo(x['score'] as double);
    if (s != 0) return s;
    return (y['w'] as int).compareTo(x['w'] as int);
  });
  Directory('local/explore/font_candidates').createSync(recursive: true);
  final done = <int>{};
  var written = 0;
  log.writeln('--- candidats (score 0-4)');
  for (final cd in cands) {
    final ix = cd['ix'] as Uint8List;
    final h =
        Object.hashAll(ix.length > 4096 ? ix.sublist(0, 4096) : ix) ^ ix.length;
    if (!done.add(h)) continue;
    final w = cd['w'] as int, hh = cd['h'] as int;
    final pal = cd['pal'] as List<int>;
    // Rendu : palette ; si la palette est entièrement transparente/uniforme,
    // repli niveaux de gris sur l'indice.
    final distinct = pal.toSet().length;
    final rgba = Uint8List(w * hh * 4);
    final maxIdx = ix.fold<int>(0, (m, v) => v > m ? v : m);
    for (var i = 0; i < ix.length; i++) {
      int argb;
      if (distinct <= 1) {
        final v = maxIdx == 0 ? 0 : ix[i] * 255 ~/ maxIdx;
        argb = 0xFF000000 | (v << 16) | (v << 8) | v;
      } else {
        argb = pal[ix[i]];
        if ((argb >> 24) == 0) argb = 0xFF202020; // transparent -> fond sombre
      }
      rgba[i * 4] = (argb >> 16) & 255;
      rgba[i * 4 + 1] = (argb >> 8) & 255;
      rgba[i * 4 + 2] = argb & 255;
      rgba[i * 4 + 3] = 255;
    }
    log.writeln(
        'cand id=${cd['id']} gim=${cd['gim']} type=${cd['type']} ${w}x$hh ink=${(cd['ink'] as double).toStringAsFixed(3)} used=${cd['used']} fill=${(cd['fill'] as double).toStringAsFixed(2)} score=${cd['score']} palDistinct=$distinct');
    if (written < 10 && (cd['score'] as double) >= 3) {
      final name =
          'local/explore/font_candidates/id${cd['id']}_gim${cd['gim']}_${w}x$hh.png';
      File(name).writeAsBytesSync(png(w, hh, rgba));
      written++;
      log.writeln('  -> $name');
    }
    if (done.length > 300) break;
  }

  // ---- ISO : SYSDIR / USRDIR / EBOOT ----
  final iso = Iso9660(readIso, File(isoPath).lengthSync());
  log.writeln('--- ISO');
  for (final dir in ['PSP_GAME', 'PSP_GAME/SYSDIR', 'PSP_GAME/USRDIR']) {
    final de = iso.locate(dir);
    for (final f in iso.list(de)) {
      log.writeln('  $dir/${f.name} ${f.isDirectory ? 'DIR' : f.size}');
    }
  }
  final ebootEntries = <String, int>{};
  for (final p in ['PSP_GAME/SYSDIR/EBOOT.BIN', 'PSP_GAME/SYSDIR/BOOT.BIN']) {
    try {
      final en = iso.locate(p);
      ebootEntries[p] = en.size;
      final d = readIso(en.offset, en.size);
      log.writeln(
          '$p size=${en.size} head=${d.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()} (7f454c46=ELF, 7e505350="~PSP")');
      final re = RegExp(
          r'font|glyph|width|pgf|pfont|kanji|moji|\.gim|\.tmh|\.bin|fnt',
          caseSensitive: false);
      final run = StringBuffer();
      var start = 0;
      var hits = 0;
      void flush(int end) {
        if (run.length >= 4) {
          final s = run.toString();
          if (re.hasMatch(s) && hits < 60) {
            hits++;
            log.writeln(
                '  str@0x${start.toRadixString(16)}: ${s.length > 80 ? s.substring(0, 80) : s}');
          }
        }
        run.clear();
      }

      for (var i = 0; i < d.length; i++) {
        final b = d[i];
        if (b >= 0x20 && b < 0x7F) {
          if (run.isEmpty) start = i;
          run.writeCharCode(b);
        } else {
          flush(i);
        }
      }
      flush(d.length);
      log.writeln('  chaînes correspondantes: $hits');
      // tables 256 octets plausibles comme largeurs (valeurs 1..40, >= 8 distinctes)
      var tabs = 0;
      var lastEnd = -1;
      final offs = <String>[];
      for (var i = 0; i + 256 <= d.length; i++) {
        if (i < lastEnd) continue;
        var ok = true;
        final set = <int>{};
        var sum = 0;
        for (var k = 0; k < 256; k++) {
          final v = d[i + k];
          if (v < 1 || v > 40) {
            ok = false;
            break;
          }
          set.add(v);
          sum += v;
        }
        if (ok && set.length >= 8) {
          tabs++;
          lastEnd = i + 256;
          if (offs.length < 20)
            offs.add(
                '0x${i.toRadixString(16)}(mean=${(sum / 256).toStringAsFixed(1)},d=${set.length})');
        }
      }
      log.writeln(
          '  tables u8 [1..40] x256 plausibles: $tabs ${offs.join(' ')}');
    } catch (ex) {
      log.writeln('$p : $ex');
    }
  }

  File('local/explore/font_gim_scan.txt').writeAsStringSync(log.toString());
  stdout.writeln(
      'TMH=$tmhFiles MIG=$migFiles GIM=$gimTotal PGF0=$pgf nestedMigFiles=${nested.length} cands=${cands.length} png=$written');
  for (final k in hk.take(15)) {
    stdout.writeln('  $k : ${hist[k]}');
  }
}
