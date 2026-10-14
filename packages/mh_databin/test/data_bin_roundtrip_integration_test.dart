import 'dart:io';
import 'dart:typed_data';

import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

void main() {
  // À valider par l'humain : MHP3_ISO=local/MHP3.iso
  // Critère de sortie de la phase 0 (docs/PROGRESS.md).
  final real = Platform.environment['MHP3_ISO'];

  test(
    'DATA.BIN réel : encrypt(decrypt(x, lba), lba) == x sur tous les fichiers',
    () async {
      final reg =
          GameVersionRegistry.fromFile('../../config/game_versions.yaml');
      final img = await FileIsoImage.open(real!, reg);
      addTearDown(img.close);

      final raf = File(real).openSync();
      addTearDown(raf.closeSync);
      final base = img.dataBin.offset;
      Uint8List readAt(int offset, int length) {
        raf.setPositionSync(base + offset);
        final out = Uint8List(length);
        var got = 0;
        while (got < length) {
          final n = raf.readIntoSync(out, got);
          if (n == 0) fail('unexpected EOF at DATA.BIN+${offset + got}');
          got += n;
        }
        return out;
      }

      const cipher = DataCipher();
      final index = DataBinIndex.build(readAt, img.dataBin.size);
      expect(index.entries, isNotEmpty);

      final failures = <int>[];
      for (final e in index.entries) {
        if (!e.encrypted) continue;
        final raw = readAt(e.offset, e.slotBytes);
        final back = cipher.encrypt(cipher.decrypt(raw, e.lba), e.lba);
        var same = back.length == raw.length;
        for (var i = 0; same && i < raw.length; i++) {
          same = back[i] == raw[i];
        }
        if (!same) failures.add(e.id);
      }
      expect(failures, isEmpty, reason: 'file ids with failed round-trip');
    },
    tags: ['integration', 'slow'],
    skip: real == null ? 'MHP3_ISO absent' : false,
  );
}
