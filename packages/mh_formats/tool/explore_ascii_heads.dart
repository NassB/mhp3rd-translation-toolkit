// ignore_for_file: type=lint
// Usage: dart run packages/mh_formats/tool/explore_ascii_heads.dart local/MHP3.iso id...
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

  const c = DataCipher();
  final idx = DataBinIndex.build(readAt, img.dataBin.size);
  final ids = a.skip(1).map(int.parse).toSet();
  for (final e in idx.entries.where((e) => ids.contains(e.id))) {
    final raw = readAt(e.offset, e.slotBytes);
    final p = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final h =
        p.take(48).map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
    print('${e.id} slot=${e.slotBytes} enc=${e.encrypted}: $h');
  }
}
