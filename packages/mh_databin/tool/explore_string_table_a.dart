// Exploration (non versionnée en données) : structure string_table_a.
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';

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
  final ids = a.length > 1 ? a.skip(1).map(int.parse).toList() : <int>[
    for (var i = 10; i <= 29; i++) i,
    for (var i = 4700; i <= 4799; i++) i,
  ];
  final stat = <String, int>{};
  void inc(String k, [int n = 1]) => stat[k] = (stat[k] ?? 0) + n;
  final unkVals = <int, int>{};
  final endZeroLead = <int, int>{};
  for (final id in ids) {
    if (id > idx.entries.length) continue;
    final e = idx.byId(id);
    if (e.slotBytes == 0) {
      inc('slot vide');
      continue;
    }
    final raw = readAt(e.offset, e.slotBytes);
    final d = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final bd = ByteData.sublistView(d);
    final n = bd.getInt32(0, Endian.little);
    final unk = bd.getInt32(4, Endian.little);
    final plausible = n > 0 &&
        n < 4096 &&
        8 + 4 * n <= d.length &&
        List.generate(n, (j) => bd.getInt32(8 + 4 * j, Endian.little))
            .every((o) => o == -1 || (o >= 8 + 4 * n && o < d.length));
    String hx(int s, int l) => d
        .sublist(s, s + l)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    out.writeln('id=$id head=${hx(0, 32)} tail=${hx(d.length - 8, 8)}');
    out.writeln('id=$id mod=${e.modId} slot=${e.slotBytes} n=$n unk=$unk ok=$plausible');
    if (!plausible) {
      inc('non plausible');
      continue;
    }
    inc('fichiers string_table_a');
    unkVals[unk] = (unkVals[unk] ?? 0) + 1;
    var maxEnd = 8 + 4 * n;
    var prevTableEnd = 8 + 4 * n;
    final tabs = [
      for (var j = 0; j < n; j++) bd.getInt32(8 + 4 * j, Endian.little)
    ];
    inc('tables total', n);
    for (var j = 0; j < n; j++) {
      final t = tabs[j];
      if (t == -1) {
        inc('table nulle');
        continue;
      }
      if (j > 0 && t < prevTableEnd) inc('table chevauche/non croissante');
      var p = t;
      final offs = <int>[];
      while (true) {
        final v = bd.getInt32(p, Endian.little);
        p += 4;
        if (v == -1) {
          inc('sentinelle -1 trouvée');
          break;
        }
        offs.add(v);
        if (p + 4 > d.length) {
          inc('sentinelle absente');
          break;
        }
      }
      final k = offs.length;
      if (k == 0) inc('table K=0');
      inc('chaînes total', k);
      // absolu vs relatif
      final firstRel = 4 * k + 4;
      if (k > 0) {
        if (offs[0] == firstRel) {
          inc('1er offset == 4K+4 (relatif table)');
        } else if (offs[0] == t + firstRel) {
          inc('1er offset == t+4K+4 (absolu)');
        } else {
          inc('1er offset autre');
          out.writeln('  autre: id=$id t=$j off0=${offs[0]} K=$k rel=$firstRel');
        }
      }
      // contiguïté
      var tableEnd = p;
      final seen = <int>{};
      var prevEnd = -1;
      for (var q = 0; q < k; q++) {
        final o = t + offs[q];
        if (o < 0 || o >= d.length) {
          inc('offset hors bornes (rel)');
          continue;
        }
        if (!seen.add(o)) inc('alias (offset dupliqué)');
        var z = o;
        while (z < d.length && d[z] != 0) {
          z++;
        }
        final len = z - o;
        if (len == 0) inc('chaîne vide');
        if (prevEnd >= 0) {
          if (o == prevEnd) {
            inc('contigu');
          } else if (o < prevEnd) {
            inc('non croissant');
          } else {
            inc('trou entre chaînes');
          }
        }
        prevEnd = z + 1;
        if (z + 1 > tableEnd) tableEnd = z + 1;
      }
      // octet de fin de table
      if (tableEnd < d.length && d[tableEnd] == 0) inc('octet 0 après dernière chaîne');
      final te = tableEnd + (tableEnd < d.length && d[tableEnd] == 0 ? 1 : 0);
      if (j + 1 < n) {
        var nx = -1;
        for (var m = j + 1; m < n; m++) {
          if (tabs[m] != -1) {
            nx = tabs[m];
            break;
          }
        }
        if (nx != -1) {
          if (nx == te) {
            inc('table suivante collée à fin (avec 0 final)');
          } else if (nx == tableEnd) {
            inc('table suivante collée sans 0 final');
          } else {
            inc('gap/align avant table suivante');
            out.writeln('  gap id=$id t=$j end=$tableEnd te=$te next=$nx');
          }
        }
      }
      prevTableEnd = te;
      if (te > maxEnd) maxEnd = te;
    }
    // endData
    final endLen = d.length - maxEnd;
    var zl = 0;
    while (maxEnd + zl < d.length && d[maxEnd + zl] == 0) {
      zl++;
    }
    endZeroLead[zl == endLen ? -1 : (zl == 0 ? 0 : 1)] =
        (endZeroLead[zl == endLen ? -1 : (zl == 0 ? 0 : 1)] ?? 0) + 1;
    out.writeln('  endData len=$endLen leadingZeros=$zl nonzeroAfter=${endLen - zl}');
    out.writeln('  endHead=${hx(maxEnd, endLen < 32 ? endLen : 32)}');
    final nz = <int>[];
    for (var q = maxEnd + zl; q < d.length && nz.length < 1; q++) {
      nz.add(q);
    }
    if (nz.isNotEmpty) {
      out.writeln('  first nonzero at +${nz[0] - maxEnd}');
    }
  }
  out.writeln('STATS');
  for (final e in stat.entries) {
    out.writeln('${e.key}: ${e.value}');
  }
  out.writeln('unknownHeader: $unkVals');
  out.writeln('endData (-1 tout zéro, 0 non nul dès début, 1 zéros puis données): $endZeroLead');
  File('local/explore/string_table_a.txt').writeAsStringSync(out.toString());
  print(out.toString().split('STATS').last);
}
