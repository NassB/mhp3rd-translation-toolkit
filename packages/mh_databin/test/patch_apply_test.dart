import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

// Builder de fixtures partagé avec mh_iso (aucune donnée du jeu).
import '../../mh_iso/test/support/iso_builder.dart';

DataBinEntry entry(int id, int lba, int sectors) => DataBinEntry(
      id: id,
      lba: lba,
      slotBytes: sectors * sectorSize,
      sha1Plain: '',
      encrypted: true,
    );

void main() {
  const dataLba = 40;
  late Directory tmp;
  late File iso;
  late Uint8List srcBytes;
  late GameVersionRegistry registry;
  late DataBinIndex index;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mh_apply_test');
    srcBytes = buildIso(const [
      FakeFile(dataBinIsoPath, dataLba, 8 * sectorSize),
    ]);
    // Motif non nul dans DATA.BIN pour détecter tout écrasement.
    for (var i = 0; i < 8 * sectorSize; i++) {
      srcBytes[dataLba * sectorSize + i] = (i * 7 + 1) & 0xFF;
    }
    iso = File('${tmp.path}/src.iso')..writeAsBytesSync(srcBytes);
    registry = GameVersionRegistry([
      GameVersion(
        id: 'TEST',
        platform: 'psp',
        isoMd5: md5.convert(srcBytes).toString(),
        databinIsoOffset: dataLba * sectorSize,
      ),
    ]);
    // TOC synthétique : id1 lba 1 (2 secteurs), id2 lba 3 (vide), id3 lba 3 (4).
    index = DataBinIndex([entry(1, 1, 2), entry(2, 3, 0), entry(3, 3, 4)]);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  PatchFile patch() => PatchFile([
        PatchBlock(
          offset: 1 * sectorSize,
          data: Uint8List(2 * sectorSize)..fillRange(0, 2 * sectorSize, 0xAA),
        ),
        PatchBlock(
          offset: 3 * sectorSize,
          data: Uint8List(sectorSize)..fillRange(0, sectorSize, 0xBB),
        ),
      ]);

  test('writes blocks in place on a copy, leaves the rest and source intact',
      () async {
    final img = await FileIsoImage.open(iso.path, registry);
    addTearDown(img.close);
    final out = '${tmp.path}/out.iso';
    await applyPatch(img, patch(), index, outPath: out);

    final result = File(out).readAsBytesSync();
    expect(result.length, srcBytes.length);
    final base = dataLba * sectorSize;
    final expected = Uint8List.fromList(srcBytes);
    expected.fillRange(base + sectorSize, base + 3 * sectorSize, 0xAA);
    expected.fillRange(base + 3 * sectorSize, base + 4 * sectorSize, 0xBB);
    expect(result, expected);
    expect(iso.readAsBytesSync(), srcBytes);
  });

  test('refuses an existing output path, source included', () async {
    final img = await FileIsoImage.open(iso.path, registry);
    addTearDown(img.close);
    await expectLater(
      applyPatch(img, patch(), index, outPath: iso.path),
      throwsA(isA<IsoError>()),
    );
    expect(iso.readAsBytesSync(), srcBytes);
  });

  test('invalid patch creates no output file', () async {
    final img = await FileIsoImage.open(iso.path, registry);
    addTearDown(img.close);
    final out = '${tmp.path}/bad.iso';
    final bad = PatchFile([
      PatchBlock(offset: 5 * sectorSize, data: Uint8List(sectorSize)),
    ]);
    await expectLater(
      applyPatch(img, bad, index, outPath: out),
      throwsA(isA<PatchError>()),
    );
    expect(File(out).existsSync(), isFalse);
  });

  test('block beyond DATA.BIN size creates no output file', () async {
    final img = await FileIsoImage.open(iso.path, registry);
    addTearDown(img.close);
    final out = '${tmp.path}/far.iso';
    // Index annonçant un slot hors de DATA.BIN (8 secteurs).
    final far = DataBinIndex([entry(1, 7, 4)]);
    final p = PatchFile([
      PatchBlock(offset: 7 * sectorSize, data: Uint8List(2 * sectorSize)),
    ]);
    await expectLater(
      applyPatch(img, p, far, outPath: out),
      throwsA(isA<PatchError>()),
    );
    expect(File(out).existsSync(), isFalse);
  });
}
