import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:test/test.dart';

Uint8List blob(int n, int v) => Uint8List(n)..fillRange(0, n, v);

DataBinEntry entry(int id, int lba, int sectors) => DataBinEntry(
      id: id,
      lba: lba,
      slotBytes: sectors * 2048,
      sha1Plain: '',
      encrypted: true,
    );

void main() {
  // Index : id1 lba 4 (2 secteurs), id2 lba 6 (vide), id3 lba 6 (3 secteurs).
  final index = DataBinIndex([entry(1, 4, 2), entry(2, 6, 0), entry(3, 6, 3)]);

  group('serialize / parse', () {
    test('header padded to 16 for N = 0..5 and data follows', () {
      for (var n = 0; n <= 5; n++) {
        final blocks = [
          for (var i = 0; i < n; i++)
            PatchBlock(offset: (i + 1) * 4096, data: blob(1024, i + 1)),
        ];
        final bytes = PatchFile(blocks).serialize();
        final headerLen = 4 + 8 * n;
        final dataOffset = headerLen + (-headerLen % 16);
        expect(bytes.length, dataOffset + 1024 * n, reason: 'N=$n');
        expect(dataOffset % 16, 0);
        for (var i = headerLen; i < dataOffset; i++) {
          expect(bytes[i], 0, reason: 'padding N=$n');
        }
        final back = PatchFile.parse(bytes);
        expect(back.blocks.length, n);
        for (var i = 0; i < n; i++) {
          expect(back.blocks[i].offset, blocks[i].offset);
          expect(back.blocks[i].data, blocks[i].data);
        }
        expect(back.serialize(), bytes);
      }
    });

    test('exact layout for one block', () {
      final bytes = PatchFile([
        PatchBlock(offset: 0x2000, data: blob(1024, 0xAB)),
      ]).serialize();
      expect(bytes.sublist(0, 12), [
        1, 0, 0, 0, //
        0, 0x20, 0, 0, //
        0, 4, 0, 0,
      ]);
      expect(bytes[12], 0);
      expect(bytes[16], 0xAB);
    });

    test('rejects length not multiple of 1024', () {
      expect(
        () =>
            PatchFile([PatchBlock(offset: 0, data: blob(1000, 1))]).serialize(),
        throwsA(isA<PatchError>()),
      );
    });

    test('parse ignores trailing bytes (install_tables tail)', () {
      final bytes = PatchFile([
        PatchBlock(offset: 2048, data: blob(1024, 7)),
      ]).serialize();
      final withTail = Uint8List.fromList([...bytes, 1, 2, 3, 4]);
      expect(PatchFile.parse(withTail).blocks.single.data, blob(1024, 7));
    });

    test('parse rejects truncated data and absurd counts', () {
      final bytes = PatchFile([
        PatchBlock(offset: 2048, data: blob(1024, 7)),
      ]).serialize();
      expect(
        () => PatchFile.parse(bytes.sublist(0, bytes.length - 1)),
        throwsA(isA<FormatError>()),
      );
      expect(
        () => PatchFile.parse(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF])),
        throwsA(isA<FormatError>()),
      );
      expect(() => PatchFile.parse(Uint8List(2)), throwsA(isA<FormatError>()));
    });
  });

  group('validate', () {
    PatchFile one(int offset, int len) =>
        PatchFile([PatchBlock(offset: offset, data: blob(len, 1))]);

    test('accepts exact slot starts within slot, including empty-slot twin',
        () {
      one(4 * 2048, 2 * 2048).validate(index);
      one(6 * 2048, 3 * 2048).validate(index);
      one(6 * 2048, 2048).validate(index);
    });

    test('rejects offset not on a file start', () {
      final p = one(5 * 2048, 2048);
      expect(() => p.validate(index), throwsA(isA<PatchError>()));
    });

    test('rejects length over slot or not sector-aligned', () {
      final big = one(4 * 2048, 3 * 2048);
      final small = one(4 * 2048, 1024);
      expect(() => big.validate(index), throwsA(isA<PatchError>()));
      expect(() => small.validate(index), throwsA(isA<PatchError>()));
    });

    test('rejects duplicate blocks', () {
      final p = PatchFile([
        PatchBlock(offset: 4 * 2048, data: blob(2048, 1)),
        PatchBlock(offset: 4 * 2048, data: blob(2048, 2)),
      ]);
      expect(() => p.validate(index), throwsA(isA<PatchError>()));
    });
  });
}
