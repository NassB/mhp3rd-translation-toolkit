import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:test/test.dart';

import 'support/data_bin_builder.dart';

void main() {
  test('index d un DATA.BIN synthétique chiffré', () {
    final db = SyntheticDataBin.build([1, 3, 2, 1], plainIndices: {1});
    final idx = DataBinIndex.build(
      db.readAt,
      db.bytes.length,
      plainIndices: {1},
    );
    expect(idx.entries, hasLength(4));
    expect(idx.entries.map((e) => e.id), [1, 2, 3, 4]);
    expect(idx.entries.map((e) => e.lba), db.starts.take(4));
    expect(idx.entries.map((e) => e.slotBytes), [2048, 6144, 4096, 2048]);
    expect(idx.entries.map((e) => e.encrypted), [true, false, true, true]);
    for (var i = 0; i < 4; i++) {
      expect(
        idx.entries[i].sha1Plain,
        sha1.convert(db.plain[i]).toString(),
        reason: 'file $i',
      );
    }
    expect(idx.byId(2).offset, db.starts[1] * sectorSize);
    expect(idx.byId(1).modId, '0000');
  });

  test('slot vide (deux entrées de TOC égales) accepté', () {
    final db = SyntheticDataBin.build([1, 0, 2]);
    final idx = DataBinIndex.build(db.readAt, db.bytes.length);
    expect(idx.entries.map((e) => e.slotBytes), [2048, 0, 4096]);
    expect(idx.entries[1].lba, idx.entries[2].lba);
  });

  test('exceptions MHP3 par défaut : indices 17-20 et 81-92 en clair', () {
    final db = SyntheticDataBin.build(
      List<int>.filled(95, 1),
      plainIndices: mhp3JpPlainIndices,
    );
    final idx = DataBinIndex.build(db.readAt, db.bytes.length);
    expect(idx.entries.where((e) => !e.encrypted), hasLength(16));
    for (final i in [0, 17, 20, 21, 80, 81, 92, 93]) {
      expect(idx.entries[i].sha1Plain, sha1.convert(db.plain[i]).toString());
    }
  });

  test('modId : ID 2470 -> 09A5', () {
    const e = DataBinEntry(
      id: 2470,
      lba: 0,
      slotBytes: 0,
      sha1Plain: '',
      encrypted: true,
    );
    expect(e.modId, '09A5');
  });

  test('byId hors bornes', () {
    final db = SyntheticDataBin.build([1]);
    final idx = DataBinIndex.build(db.readAt, db.bytes.length);
    expect(() => idx.byId(0), throwsA(isA<FormatError>()));
    expect(() => idx.byId(2), throwsA(isA<FormatError>()));
  });

  group('TOC invalide', () {
    test('taille non multiple de 2048', () {
      final db = SyntheticDataBin.build([1]);
      expect(
        () => DataBinToc.parse(db.readAt, db.bytes.length - 1),
        throwsA(isA<FormatError>()),
      );
    });

    test('sentinelle absente', () {
      final db = SyntheticDataBin.build([1, 1]);
      final bigger = Uint8List(db.bytes.length + 2048)..setAll(0, db.bytes);
      expect(
        () => DataBinToc.parse(
          (o, l) => Uint8List.sublistView(bigger, o, o + l),
          bigger.length,
        ),
        throwsA(isA<FormatError>()),
      );
    });

    test('TOC lue au-delà du conteneur', () {
      final db = SyntheticDataBin.build([1, 1]);
      expect(
        () => DataBinToc.parse(db.readAt, 2048 * 100),
        throwsA(anything),
      );
    });

    test('TOC couvrant tout le fichier', () {
      final db = SyntheticDataBin.build([1, 1]);
      expect(
        () => DataBinToc.parse(db.readAt, 2048),
        throwsA(isA<FormatError>()),
      );
    });

    test('TOC non croissante', () {
      final w = ByteWriter()
        ..u32(1)
        ..u32(3)
        ..u32(2)
        ..u32(4)
        ..padTo(sectorSize);
      final toc = const DataCipher().encrypt(w.toBytes(), 0);
      final file = Uint8List(4 * sectorSize)..setAll(0, toc);
      expect(
        () => DataBinToc.parse(
          (o, l) => Uint8List.sublistView(file, o, o + l),
          file.length,
        ),
        throwsA(isA<FormatError>()),
      );
    });
  });
}
