// ignore_for_file: type=lint
// Exploration : décode les GIM standards (IDs passés) en PNG de candidats. Lecture seule.
import 'dart:io';
import 'dart:typed_data';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';
import 'explore_font.dart' show png;

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
  for (final id in a.skip(1).map(int.parse)) {
    final e = idx.byId(id);
    final raw = readAt(e.offset, e.slotBytes);
    final d = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    String hx(int s, int l) => d
        .sublist(s, s + l)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    stdout.writeln('id=$id img hdr: ${hx(0x40, 48)}');
    final po = id == 22 ? 0x10090 : 0x22b90;
    stdout.writeln(
        'id=$id pal hdr: ${hx(po, 48)} first colors: ${hx(po + 48, 16)}');
    final bd = ByteData.sublistView(d);
    final w = bd.getUint16(0x48, Endian.little),
        h = bd.getUint16(0x4A, Endian.little);
    final swz = bd.getUint16(0x46, Endian.little) == 1;
    final px = Uint8List(w * h);
    final src = 0x70;
    if (!swz) {
      px.setRange(0, w * h, d, src);
    } else {
      var k = 0;
      for (var sy = 0; sy < h ~/ 8; sy++) {
        for (var sx = 0; sx < w ~/ 16; sx++) {
          for (var y = 0; y < 8; y++) {
            for (var x = 0; x < 16; x++) {
              px[(sy * 8 + y) * w + sx * 16 + x] = d[src + k++];
            }
          }
        }
      }
    }
    final rgba = Uint8List(w * h * 4);
    final cs = bd.getUint16(po + 4, Endian.little); // format palette
    for (var i = 0; i < w * h; i++) {
      final o = po + 48 + px[i] * 4;
      rgba[i * 4] = d[o];
      rgba[i * 4 + 1] = d[o + 1];
      rgba[i * 4 + 2] = d[o + 2];
      rgba[i * 4 + 3] = 255;
    }
    File('local/explore/font_candidates/std_gim_id${id}_${w}x$h.png')
        .writeAsBytesSync(png(w, h, rgba));
    stdout.writeln('id=$id ${w}x$h swizzled=$swz palFormat=$cs');
  }
}
