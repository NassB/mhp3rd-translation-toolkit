// ignore_for_file: type=lint
// Exploration : magics des fichiers de DATA.BIN et tags évoquant une police. Lecture seule.
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
  final tags = <String, List<int>>{
    'PGF0': 'PGF0'.codeUnits,
    'FONT': 'FONT'.codeUnits,
    'font': 'font'.codeUnits,
    'glyph': 'glyph'.codeUnits,
    'cmap': 'cmap'.codeUnits,
    'OTTO': 'OTTO'.codeUnits,
    'FNT': 'FNT'.codeUnits,
    'fnt': 'fnt'.codeUnits,
    'pgf': 'pgf'.codeUnits,
    'ttf': 'ttf'.codeUnits,
    'kanji': 'kanji'.codeUnits,
    'KANJI': 'KANJI'.codeUnits,
  };
  final tagFiles = <String, List<int>>{};
  final magics = <String, int>{};
  final magicIds = <String, List<int>>{};
  final out = StringBuffer();
  for (final e in idx.entries) {
    if (e.slotBytes == 0) continue;
    final raw = readAt(e.offset, e.slotBytes);
    final d = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final m =
        d.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    magics[m] = (magics[m] ?? 0) + 1;
    (magicIds[m] ??= []).add(e.id);
    for (final t in tags.entries) {
      final p = t.value;
      outer:
      for (var i = 0; i + p.length <= d.length; i++) {
        if (d[i] != p[0]) continue;
        for (var k = 1; k < p.length; k++) {
          if (d[i + k] != p[k]) continue outer;
        }
        (tagFiles[t.key] ??= []).add(e.id);
        break;
      }
    }
  }
  final mk = magics.keys.toList()
    ..sort((x, y) => magics[y]!.compareTo(magics[x]!));
  for (final k in mk.take(40)) {
    final ids = magicIds[k]!;
    out.writeln(
        'magic $k : ${magics[k]} fichiers, ex. ids ${ids.take(6).join(',')}');
  }
  out.writeln('magics distincts: ${magics.length}');
  for (final t in tagFiles.entries) {
    out.writeln(
        'tag ${t.key}: ${t.value.length} fichiers, ex. ${t.value.take(10).join(',')}');
  }
  File('local/explore/font_magic.txt').writeAsStringSync(out.toString());
  stdout.write(out.toString());
}
