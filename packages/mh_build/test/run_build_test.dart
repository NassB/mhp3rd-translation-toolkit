import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

// Builder d'ISO partagé avec mh_iso (aucune donnée du jeu).
import '../../mh_iso/test/support/iso_builder.dart';
import 'support/build_fixtures.dart';

void main() {
  const dataLba = 40;
  late Directory tmp;
  late File iso;
  late Uint8List srcBytes;
  late FileIsoImage image;
  late TdbDatabase db;
  late StringTableFile original;
  late Uint8List plain;
  late DataBinIndex index;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mh_build_test');
    original = model();
    plain = slotBytesOf(original);
    index = DataBinIndex([entry()]);
    srcBytes = buildIso(const [
      FakeFile(dataBinIsoPath, dataLba, 8 * sectorSize),
    ]);
    final enc = const DataCipher().encrypt(plain, 5);
    srcBytes.setRange(
      (dataLba + 5) * sectorSize,
      (dataLba + 6) * sectorSize,
      enc,
    );
    iso = File('${tmp.path}/src.iso')..writeAsBytesSync(srcBytes);
    image = await FileIsoImage.open(
      iso.path,
      GameVersionRegistry([
        GameVersion(
          id: 'TEST',
          platform: 'psp',
          isoMd5: md5.convert(srcBytes).toString(),
          databinIsoOffset: dataLba * sectorSize,
        ),
      ]),
    );
    db = TdbDatabase.openInMemory();
    await importSourceFile(
      db,
      fileId: 1,
      versionId: 'TEST',
      lba: 5,
      slotBytes: 2048,
      origBytes: 2048,
      file: original,
    );
  });

  tearDown(() async {
    image.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> translate(String line) => importMhtoolsTranslations(
        db,
        fileId: 1,
        original: original,
        dump: dump([line, 'trois', line]),
        locale: 'fr',
        status: 'translated',
      );

  Future<BuildRun> run(String name) => runBuild(
        db: db,
        iso: image,
        index: index,
        readPlain: (_) => plain,
        locale: 'fr',
        outPath: '${tmp.path}/$name.iso',
        toolkitVersion: '0.0.1',
      );

  test('writes a verified copy, records the build, leaves the source',
      () async {
    await translate('UN');
    final r = await run('out');
    expect(r.status, BuildStatus.ok);
    expect(r.verifyErrors, isEmpty);
    expect(r.tdbRevision, 1);

    final out = File('${tmp.path}/out.iso').readAsBytesSync();
    expect(out.length, srcBytes.length);
    final lo = (dataLba + 5) * sectorSize;
    final hi = lo + sectorSize;
    expect(out.sublist(0, lo), srcBytes.sublist(0, lo));
    expect(out.sublist(hi), srcBytes.sublist(hi));
    expect(out.sublist(lo, hi), isNot(srcBytes.sublist(lo, hi)));
    expect(iso.readAsBytesSync(), srcBytes);

    final row = await db.select(db.builds).getSingle();
    expect(row.id, r.buildId);
    expect(row.status, 'ok');
    expect(row.tdbRevision, 1);
    expect(row.isoMd5, image.version.isoMd5);
    final json = jsonDecode(row.reportJson!) as Map<String, Object?>;
    expect(json['status'], 'ok');
    expect((json['files']! as List).single, containsPair('file_id', 1));
  });

  test('budget overflow writes no ISO but records the build', () async {
    await translate('x' * 2000);
    final r = await run('big');
    expect(r.status, BuildStatus.budgetExceeded);
    expect(File('${tmp.path}/big.iso').existsSync(), isFalse);
    expect((await db.select(db.builds).getSingle()).status, 'budget_exceeded');
  });

  test('nothing to build writes no ISO', () async {
    final r = await run('none');
    expect(r.status, BuildStatus.nothingToBuild);
    expect(r.tdbRevision, 0);
    expect(File('${tmp.path}/none.iso').existsSync(), isFalse);
    expect((await db.select(db.builds).getSingle()).status, 'nothing_to_build');
  });

  test('tdbRevision grows with each modification', () async {
    expect(await tdbRevision(db), 0);
    await translate('UN');
    expect(await tdbRevision(db), 1);
    await translate('DEUX');
    expect(await tdbRevision(db), 2);
  });

  test('refuses an existing output path', () async {
    await translate('UN');
    await run('twice');
    await expectLater(run('twice'), throwsA(isA<IsoError>()));
  });
}
