import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

import 'support/iso_builder.dart';

void main() {
  const dataBin = 'PSP_GAME/USRDIR/DATA.BIN';
  final image = buildIso(const [
    FakeFile(dataBin, 40, 5000),
    FakeFile('PSP_GAME/PARAM.SFO', 30, 100),
  ]);

  test('mh_iso se charge', () {
    expect(mhIsoPackageName, 'mh_iso');
  });

  test('locate retrouve DATA.BIN', () {
    final e = Iso9660.fromBytes(image).locate(dataBin);
    expect(e.lba, 40);
    expect(e.offset, 40 * sectorSize);
    expect(e.size, 5000);
    expect(e.isDirectory, isFalse);
    expect(e.name, 'DATA.BIN');
  });

  test('locate ignore la casse et les / superflus', () {
    final e = Iso9660.fromBytes(image).locate('/psp_game/usrdir/data.bin');
    expect(e.lba, 40);
  });

  test('list exclut . et ..', () {
    final iso = Iso9660.fromBytes(image);
    final names = iso.list(iso.locate('PSP_GAME')).map((e) => e.name);
    expect(names, unorderedEquals(['USRDIR', 'PARAM.SFO']));
  });

  test('chemin absent -> IsoError', () {
    final iso = Iso9660.fromBytes(image);
    expect(() => iso.locate('PSP_GAME/NOPE.BIN'), throwsA(isA<IsoError>()));
    expect(() => iso.locate('$dataBin/X'), throwsA(isA<IsoError>()));
  });

  test('PVD invalide -> IsoError', () {
    final bad = buildIso(const [FakeFile('A.BIN', 20, 10)], validPvd: false);
    expect(() => Iso9660.fromBytes(bad), throwsA(isA<IsoError>()));
  });

  test('image tronquée -> IsoError', () {
    final cut = Uint8List.sublistView(image, 0, 16 * sectorSize + 100);
    expect(() => Iso9660.fromBytes(cut), throwsA(isA<IsoError>()));
  });

  test('enregistrement de répertoire corrompu -> IsoError', () {
    final bad = Uint8List.fromList(image);
    // Premier enregistrement du répertoire racine (LBA 18) : longueur 10 < 34.
    bad[18 * sectorSize] = 10;
    final iso = Iso9660.fromBytes(bad);
    expect(() => iso.locate(dataBin), throwsA(isA<IsoError>()));
  });
}
