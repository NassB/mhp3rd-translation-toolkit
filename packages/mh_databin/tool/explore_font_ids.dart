// ignore_for_file: type=lint
// Exploration : tête, taille et chaînes ASCII (filtrées) de quelques IDs. Lecture seule.
import 'dart:io';
import 'dart:typed_data';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';

Future<void> main(List<String> a) async {
  final reg = GameVersionRegistry.fromFile('config/game_versions.yaml');
  final img = await FileIsoImage.open(a[0], reg);
  final raf = File(a[0]).openSync();
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

  final idx = DataBinIndex.build(readAt, img.dataBin.size);
  const c = DataCipher();
  final re = RegExp(
      r'font|Font|FONT|glyph|pgf|PGF|fnt|FNT|ttf|sceFont|libfont|SJIS|cmap',
      caseSensitive: true);
  for (final id in a.skip(1).map(int.parse)) {
    final e = idx.byId(id);
    final raw = readAt(e.offset, e.slotBytes);
    final d = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    String hx(int s, int l) => d
        .sublist(s, s + l)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');
    stdout.writeln(
        'id=$id slot=${e.slotBytes} enc=${e.encrypted} head=${hx(0, 32)}');
    final run = StringBuffer();
    var start = 0, hits = 0;
    void flush() {
      if (run.length >= 5) {
        final s = run.toString();
        if (re.hasMatch(s) && hits < 8) {
          hits++;
          stdout.writeln(
              '   str@0x${start.toRadixString(16)}: ${s.length > 60 ? s.substring(0, 60) : s}');
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
        flush();
      }
    }
    flush();
  }
}
