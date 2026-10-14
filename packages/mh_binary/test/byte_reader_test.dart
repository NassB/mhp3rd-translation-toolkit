import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:test/test.dart';

void main() {
  final data = Uint8List.fromList([
    0x01, // u8
    0x34, 0x12, // u16 = 0x1234
    0x78, 0x56, 0x34, 0x12, // u32 = 0x12345678
    0xFF, 0xFF, 0xFF, 0xFF, // u32 = 0xFFFFFFFF / i32 = -1
    0xAA, 0xBB, 0xCC,
  ]);

  test('lectures little-endian séquentielles', () {
    final r = ByteReader(data);
    expect(r.u8(), 1);
    expect(r.u16(), 0x1234);
    expect(r.u32(), 0x12345678);
    expect(r.u32(), 0xFFFFFFFF);
    expect(r.position, 11);
    expect(r.remaining, 3);
  });

  test('i32 signé', () {
    final r = ByteReader(data)..seek(7);
    expect(r.i32(), -1);
  });

  test('bytes retourne les octets attendus', () {
    final r = ByteReader(data)..seek(11);
    expect(r.bytes(3), [0xAA, 0xBB, 0xCC]);
    expect(r.remaining, 0);
    expect(r.bytes(0), isEmpty);
  });

  test('fonctionne sur une sublistView avec offset non nul', () {
    final view = Uint8List.sublistView(data, 1, 5);
    final r = ByteReader(view);
    expect(r.u16(), 0x1234);
    expect(r.u16(), 0x5678);
  });

  test('seek et skip', () {
    final r = ByteReader(data)
      ..seek(3)
      ..skip(2);
    expect(r.position, 5);
    r.skip(-1);
    expect(r.position, 4);
    r.seek(data.length); // borne haute autorisée
    expect(r.remaining, 0);
  });

  group('hors bornes → FormatError avec offset', () {
    FormatError catchErr(void Function() f) {
      try {
        f();
      } on FormatError catch (e) {
        return e;
      }
      fail('FormatError attendue');
    }

    test('u32 tronqué', () {
      final r = ByteReader(data, fileId: 7)..seek(12);
      final e = catchErr(r.u32);
      expect(e.offset, 12);
      expect(e.fileId, 7);
      expect(e.toString(), contains('offset=0xc'));
      expect(r.position, 12, reason: 'curseur inchangé après erreur');
    });

    test('u8 en fin de tampon', () {
      final r = ByteReader(data)..seek(data.length);
      expect(catchErr(r.u8).offset, data.length);
    });

    test('bytes trop long ou négatif', () {
      final r = ByteReader(data);
      expect(catchErr(() => r.bytes(100)).offset, 0);
      expect(catchErr(() => r.bytes(-1)).offset, 0);
    });

    test('seek/skip invalides', () {
      final r = ByteReader(data);
      expect(catchErr(() => r.seek(-1)).offset, -1);
      expect(catchErr(() => r.seek(data.length + 1)).offset, data.length + 1);
      expect(catchErr(() => r.skip(-1)).offset, -1);
    });
  });
}
