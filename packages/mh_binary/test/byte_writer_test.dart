import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:test/test.dart';

void main() {
  group('ByteWriter', () {
    test('écriture puis relecture identique', () {
      final w = ByteWriter(initialCapacity: 1)
        ..u8(0xAB)
        ..u16(0xBEEF)
        ..u32(0xDEADBEEF)
        ..i32(-2)
        ..bytes(Uint8List.fromList([1, 2, 3]));
      final r = ByteReader(w.toBytes());
      expect(r.u8(), 0xAB);
      expect(r.u16(), 0xBEEF);
      expect(r.u32(), 0xDEADBEEF);
      expect(r.i32(), -2);
      expect(r.bytes(3), [1, 2, 3]);
      expect(r.remaining, 0);
    });

    test('little-endian', () {
      final w = ByteWriter()..u32(0x01020304);
      expect(w.toBytes(), [4, 3, 2, 1]);
    });

    test('croissance au-delà de la capacité initiale', () {
      final w = ByteWriter(initialCapacity: 16);
      for (var i = 0; i < 1000; i++) {
        w.u32(i);
      }
      expect(w.length, 4000);
      final r = ByteReader(w.toBytes());
      for (var i = 0; i < 1000; i++) {
        expect(r.u32(), i);
      }
    });

    test('valeurs hors plage', () {
      expect(() => ByteWriter().u8(256), throwsA(isA<FormatError>()));
      expect(() => ByteWriter().u16(-1), throwsA(isA<FormatError>()));
      expect(() => ByteWriter().u32(0x100000000), throwsA(isA<FormatError>()));
      expect(() => ByteWriter().i32(0x80000000), throwsA(isA<FormatError>()));
    });

    test('padTo et fill', () {
      final w = ByteWriter()
        ..u8(1)
        ..padTo(4);
      expect(w.toBytes(), [1, 0, 0, 0]);
      w.padTo(4);
      expect(w.length, 4);
      w.fill(2, 0xFF);
      expect(w.toBytes().sublist(4), [0xFF, 0xFF]);
    });
  });

  group('alignUp', () {
    test('secteur', () {
      expect(alignUp(0, sectorSize), 0);
      expect(alignUp(1, sectorSize), 2048);
      expect(alignUp(2048, sectorSize), 2048);
      expect(alignUp(2049, sectorSize), 4096);
    });

    test('arguments invalides', () {
      expect(() => alignUp(-1, 4), throwsA(isA<FormatError>()));
      expect(() => alignUp(1, 0), throwsA(isA<FormatError>()));
    });
  });

  test('hiérarchie MhError', () {
    const errs = <MhError>[
      FormatError('a'),
      CryptoError('b'),
      PatchError('c'),
      IsoError('d', offset: 16, fileId: 3),
    ];
    expect(errs.last.toString(), 'IsoError: d [file=3, offset=0x10]');
  });
}
