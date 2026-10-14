import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';

/// Construit un `DATA.BIN` synthétique : TOC chiffrée au LBA 0, fichiers
/// chiffrés à leur LBA (sauf `plainIndices`, stockés en clair).
///
/// `sectorCounts` : taille de chaque fichier en secteurs. Le contenu en clair
/// du fichier i est `(i * 31 + j) & 0xFF` pour l'octet j.
final class SyntheticDataBin {
  SyntheticDataBin._(this.bytes, this.starts, this.plain);

  factory SyntheticDataBin.build(
    List<int> sectorCounts, {
    Set<int> plainIndices = const {},
    int? tocSectors,
  }) {
    const cipher = DataCipher();
    final n = sectorCounts.length;
    final toc = tocSectors ?? alignUp((n + 1) * 4, sectorSize) ~/ sectorSize;
    final starts = <int>[toc];
    for (final c in sectorCounts) {
      starts.add(starts.last + c);
    }
    final tocPlain = ByteWriter();
    starts.forEach(tocPlain.u32);
    tocPlain.padTo(toc * sectorSize);
    final w = ByteWriter()..bytes(cipher.encrypt(tocPlain.toBytes(), 0));
    final plain = <Uint8List>[];
    for (var i = 0; i < n; i++) {
      final len = sectorCounts[i] * sectorSize;
      final p = Uint8List.fromList(
        List<int>.generate(len, (j) => (i * 31 + j) & 0xff),
      );
      plain.add(p);
      w.bytes(plainIndices.contains(i) ? p : cipher.encrypt(p, starts[i]));
    }
    return SyntheticDataBin._(w.toBytes(), starts, plain);
  }

  final Uint8List bytes;

  /// Débuts en secteurs, sentinelle incluse.
  final List<int> starts;

  /// Contenu en clair de chaque fichier.
  final List<Uint8List> plain;

  Uint8List readAt(int offset, int length) =>
      Uint8List.sublistView(bytes, offset, offset + length);
}
