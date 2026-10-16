// ignore_for_file: type=lint
// Exploration : arbre de chunks des GIM standards (IDs 22, 23). Lecture seule.
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
  final out = StringBuffer();
  for (final id in a.skip(1).map(int.parse)) {
    final e = idx.byId(id);
    final raw = readAt(e.offset, e.slotBytes);
    final d = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final bd = ByteData.sublistView(d);
    out.writeln('id=$id slot=${e.slotBytes} enc=${e.encrypted}');
    void walk(int pos, int end, int depth) {
      while (pos + 16 <= end) {
        final type = bd.getUint16(pos, Endian.little);
        final len = bd.getUint32(pos + 4, Endian.little);
        final next = bd.getUint32(pos + 8, Endian.little);
        final data = bd.getUint32(pos + 12, Endian.little);
        out.writeln(
            '${'  ' * depth}@0x${pos.toRadixString(16)} type=0x${type.toRadixString(16)} len=$len next=$next data=$data');
        if (len < 16 || pos + len > d.length) {
          out.writeln('${'  ' * depth}  (bad len)');
          return;
        }
        // conteneurs : 0x02 root, 0x03 file, 0x04 image, 0x05 pixels/palette?
        if (type == 0x02 ||
            type == 0x03 ||
            type == 0x04 ||
            type == 0x05 ||
            type == 0x06 ||
            type == 0x08) {
          walk(pos + 16, pos + len, depth + 1);
        } else if (type == 0x07 || type == 0x08 || type == 0x05) {}
        if (type == 0x04 || type == 0x05) {
          // en-tête image: format, order, w, h  (à vérifier)
        }
        if (len == 0) break;
        pos += len;
      }
    }

    // en-tête 16 octets "MIG.00.1PSP\0..."
    walk(16, d.length, 0);
  }
  File('local/explore/font_gim22.txt').writeAsStringSync(out.toString());
  stdout.write(out.toString().split('\n').take(60).join('\n'));
}
