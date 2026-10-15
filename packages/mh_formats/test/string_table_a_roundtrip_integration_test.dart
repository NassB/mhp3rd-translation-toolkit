import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  // À valider par l'humain : MHP3_ISO=local/MHP3.iso (tâche T13).
  final real = Platform.environment['MHP3_ISO'];

  test(
    'DATA.BIN réel : round-trip bit à bit de tous les string_table_a détectés',
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

      // Détection : le décodeur est strict (layout non canonique -> FormatError),
      // donc un décodage réussi identifie un string_table_a.
      final detected = <int>[];
      final mismatch = <int>[];
      final badMeasure = <int>[];
      final badTokens = <int>[];
      for (final e in index.entries) {
        if (e.slotBytes == 0) continue;
        final raw = readAt(e.offset, e.slotBytes);
        final plain = e.encrypted ? cipher.decrypt(raw, e.lba) : raw;
        final StringTableFile file;
        try {
          file = decodeStringTableA(plain, fileId: e.id);
        } on FormatError {
          continue;
        }
        // Un décodage strict réussi ne suffit pas : un binaire commençant par
        // 4 octets nuls (tablesCount = 0) passe (703 faux positifs, voir
        // docs/PROGRESS.md). On exige une table non nulle et un slot non vide.
        final hasText = file.tables.any(
          (t) => t != null && t.slots.any((s) => s.raw.isNotEmpty),
        );
        if (!hasText) continue;
        detected.add(e.id);
        final enc = encodeStringTableA(file, fileId: e.id);
        if (enc.length != plain.length) {
          mismatch.add(e.id);
          continue;
        }
        var same = true;
        for (var i = 0; same && i < enc.length; i++) {
          same = enc[i] == plain[i];
        }
        if (!same) mismatch.add(e.id);
        if (measureStringTableA(file, fileId: e.id) != enc.length) {
          badMeasure.add(e.id);
        }
        for (final t in file.tables.whereType<StringTable>()) {
          for (final s in t.slots) {
            final tokens = tokenizeText(s.raw, fileId: e.id);
            if (tokensByteLength(tokens) != s.raw.length ||
                !_same(detokenizeText(tokens), s.raw)) {
              badTokens.add(e.id);
              break;
            }
          }
        }
      }

      // ignore: avoid_print
      print('string_table_a détectés: ${detected.length} fichiers');
      // Corpus constaté sur l'ISO réelle (explore-data, 2026-10-15).
      expect(detected, [17, for (var i = 2813; i <= 2819; i++) i]);
      expect(mismatch, isEmpty, reason: 'file ids with failed round-trip');
      expect(badMeasure, isEmpty, reason: 'file ids with measure != length');
      expect(badTokens, isEmpty, reason: 'file ids with token round-trip loss');
    },
    tags: ['integration', 'slow'],
    skip: real == null ? 'MHP3_ISO absent' : false,
  );
}
