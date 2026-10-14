import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_cli/mh_cli.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:test/test.dart';

/// DATA.BIN synthétique : fichiers chiffrés de [counts] secteurs.
List<int> _build(List<int> counts) {
  const cipher = DataCipher();
  final toc = alignUp((counts.length + 1) * 4, sectorSize) ~/ sectorSize;
  final starts = <int>[toc];
  for (final c in counts) {
    starts.add(starts.last + c);
  }
  final tocPlain = ByteWriter();
  starts.forEach(tocPlain.u32);
  tocPlain.padTo(toc * sectorSize);
  final w = ByteWriter()..bytes(cipher.encrypt(tocPlain.toBytes(), 0));
  for (var i = 0; i < counts.length; i++) {
    w.fill(counts[i] * sectorSize, 0x5A);
  }
  return w.toBytes();
}

void main() {
  test('mhtk index résume une fixture', () async {
    final dir = Directory.systemTemp.createTempSync('mhtk');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/DATA.BIN')..writeAsBytesSync(_build([1, 3, 2]));
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runIndex([f.path], out, err);
    expect(code, 0, reason: '$err');
    expect(out.toString(), contains('files:        3'));
    expect(out.toString(), contains('largest slot: 6144 bytes (id 2'));
    expect(out.toString(), contains('total slots:  12288 bytes'));
  });

  test('arguments invalides et fichier absent', () async {
    final err = StringBuffer();
    expect(await runIndex([], StringBuffer(), err), 64);
    expect(await runIndex(['/nonexistent/DATA.BIN'], StringBuffer(), err), 1);
  });
}
