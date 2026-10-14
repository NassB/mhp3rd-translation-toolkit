import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

import 'support/iso_builder.dart';

void main() {
  late Directory tmp;
  late File iso;
  late String md5Hex;

  GameVersionRegistry registry({int lba = 40, String? md5}) =>
      GameVersionRegistry([
        GameVersion(
          id: 'TEST',
          platform: 'psp',
          isoMd5: md5 ?? md5Hex,
          databinIsoOffset: lba * sectorSize,
        ),
      ]);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mh_iso_test');
    final bytes = buildIso(const [
      FakeFile(dataBinIsoPath, 40, 5000),
      FakeFile('PSP_GAME/PARAM.SFO', 30, 100),
    ]);
    // Contenu non nul au début de DATA.BIN pour vérifier les lectures.
    for (var i = 0; i < 16; i++) {
      bytes[40 * sectorSize + i] = i + 1;
    }
    iso = File('${tmp.path}/src.iso')..writeAsBytesSync(bytes);
    md5Hex = md5.convert(bytes).toString();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('open identifie la version et DATA.BIN', () async {
    final img = await FileIsoImage.open(iso.path, registry());
    addTearDown(img.close);
    expect(img.version.id, 'TEST');
    expect(img.dataBin.lba, 40);
    expect(img.locate('PSP_GAME/PARAM.SFO').size, 100);
  });

  test('open refuse une ISO inconnue', () {
    expect(
      FileIsoImage.open(iso.path, registry(md5: 'a' * 32)),
      throwsA(isA<IsoError>()),
    );
  });

  test('open refuse un offset DATA.BIN divergent', () {
    expect(
      FileIsoImage.open(iso.path, registry(lba: 41)),
      throwsA(
        isA<IsoError>().having((e) => e.message, 'message', contains('offset')),
      ),
    );
  });

  test('openRead lit la plage demandée et vérifie les bornes', () async {
    final img = await FileIsoImage.open(iso.path, registry());
    addTearDown(img.close);
    final chunks = await img.openRead(img.dataBin, start: 2, end: 6).toList();
    expect(chunks.expand<int>((c) => c).toList(), [3, 4, 5, 6]);
    expect(
      () => img.openRead(img.dataBin, end: 5001),
      throwsA(isA<IsoError>()),
    );
  });

  test('cloneTo copie à l\'identique sans toucher la source', () async {
    final before = iso.readAsBytesSync();
    final img = await FileIsoImage.open(iso.path, registry());
    addTearDown(img.close);
    final out = '${tmp.path}/copy.iso';
    final clone = await img.cloneTo(out);
    addTearDown(clone.close);
    expect(clone.path, out);
    expect(clone.version.id, 'TEST');
    expect(File(out).readAsBytesSync(), before);
    expect(iso.readAsBytesSync(), before);
  });

  test('cloneTo refuse d\'écraser un fichier, source comprise', () async {
    final img = await FileIsoImage.open(iso.path, registry());
    addTearDown(img.close);
    final before = iso.readAsBytesSync();
    await expectLater(img.cloneTo(iso.path), throwsA(isA<IsoError>()));
    expect(iso.readAsBytesSync(), before);
    final other = File('${tmp.path}/other.iso')..writeAsStringSync('x');
    await expectLater(img.cloneTo(other.path), throwsA(isA<IsoError>()));
  });

  // À valider par l'humain : MHP3_ISO=local/MHP3.iso
  final real = Platform.environment['MHP3_ISO'];
  test(
    'ISO réelle : version reconnue et offset DATA.BIN conforme',
    () async {
      final reg =
          GameVersionRegistry.fromFile('../../config/game_versions.yaml');
      final img = await FileIsoImage.open(real!, reg);
      addTearDown(img.close);
      expect(img.dataBin.offset, img.version.databinIsoOffset);
    },
    tags: 'integration',
    skip: real == null ? 'MHP3_ISO absent' : false,
  );
}
