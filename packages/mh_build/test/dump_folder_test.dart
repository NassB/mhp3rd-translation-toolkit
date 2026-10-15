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

import '../../mh_iso/test/support/iso_builder.dart';
import 'support/build_fixtures.dart';

void main() {
  const dataLba = 40;
  late Directory tmp;
  late String config;
  late Project project;
  late TdbDatabase db;
  late StringTableFile original;
  late Uint8List plain;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mh_dump_folder');
    original = model();
    plain = slotBytesOf(original);
    final iso = buildIso(const [
      FakeFile(dataBinIsoPath, dataLba, 8 * sectorSize),
    ]);
    iso.setRange(
      (dataLba + 5) * sectorSize,
      (dataLba + 6) * sectorSize,
      const DataCipher().encrypt(plain, 5),
    );
    final isoPath = '${tmp.path}/game.iso';
    File(isoPath).writeAsBytesSync(iso);
    config = '${tmp.path}/versions.yaml';
    File(config).writeAsStringSync(
      '- id: TEST\n'
      '  platform: psp\n'
      '  iso_md5: ${md5.convert(iso)}\n'
      '  databin_iso_offset: ${dataLba * sectorSize}\n',
    );
    project = Project(
      dir: tmp.path,
      isoPath: isoPath,
      versionId: 'TEST',
      locale: 'fr',
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
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Directory dumpDir(String name, List<String> lines) {
    final d = Directory('${tmp.path}/$name')..createSync();
    File('${d.path}/filelist.txt').writeAsStringSync('0001.bin 2048\n');
    File('${d.path}/string_table_0.txt')
        .writeAsStringSync('${lines.join('\n')}\n');
    return d;
  }

  test('readOriginalFile decodes the slot without the full index', () async {
    final r = await readOriginalFile(project, db, 1, config: config);
    expect(r.size, 2048);
    expect(encodeStringTableA(r.file), plain);
  });

  test('readOriginalFile rejects unknown files, versions and bad slots',
      () async {
    await expectLater(
      readOriginalFile(project, db, 9, config: config),
      throwsA(isA<TdbError>()),
    );
    final other = Project(
      dir: project.dir,
      isoPath: project.isoPath,
      versionId: 'NOPE',
      locale: 'fr',
    );
    await expectLater(
      readOriginalFile(other, db, 1, config: config),
      throwsA(isA<IsoError>()),
    );
    // Slot hors de l'ISO.
    await importSourceFile(
      db,
      fileId: 2,
      versionId: 'TEST',
      lba: 1000000,
      slotBytes: 2048,
      origBytes: 2048,
      file: original,
    );
    await expectLater(
      readOriginalFile(project, db, 2, config: config),
      throwsA(isA<IsoError>()),
    );
  });

  test('readMhtoolsDumpFolder: null tables, endData, missing folder', () {
    final d = dumpDir('d1', ['a', 'b', 'a']);
    File('${d.path}/enddata.bin').writeAsBytesSync([1, 2, 3]);
    final dump = readMhtoolsDumpFolder(d.path, 2);
    expect(dump.tableTexts[0], 'a\nb\na\n');
    expect(dump.tableTexts[1], isNull);
    expect(dump.endData, [1, 2, 3]);
    expect(
      () => readMhtoolsDumpFolder('${tmp.path}/absent', 2),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('importDumpFolder applies a dump and returns the change count',
      () async {
    final d = dumpDir('d2', ['UN<NEWLINE>DEUX', 'trois', 'UN<NEWLINE>DEUX']);
    final n = await importDumpFolder(
      db: db,
      project: project,
      config: config,
      fileId: 1,
      folder: d.path,
      status: 'translated',
    );
    expect(n, 1);
    final repo = TranslationRepository(db, locale: 'fr');
    final first = (await repo.slots(1)).first;
    expect(first.translation!.text, 'UN\nDEUX');
    expect(first.translation!.status, 'translated');
  });

  test('exportDumpFolder writes the translations and keeps endData', () async {
    final repo = TranslationRepository(db, locale: 'fr');
    final slots = await repo.slots(1);
    await repo.saveTranslation(
      sourceId: slots[0].sourceId,
      text: 'UN\nDEUX',
      status: 'translated',
    );
    final out = '${tmp.path}/export';
    final tables = await exportDumpFolder(
      db: db,
      project: project,
      config: config,
      fileId: 1,
      folder: out,
    );
    expect(tables, 1); // la table 1 est nulle : pas de fichier
    final list = File('$out/filelist.txt').readAsStringSync();
    expect(list, startsWith('0001.bin 2048'));
    expect(
      File('$out/string_table_0.txt').readAsStringSync(),
      'UN<NEWLINE>DEUX\ntrois\nUN<NEWLINE>DEUX\n', // l'alias reprend la cible
    );
    expect(File('$out/string_table_1.txt').existsSync(), isFalse);
    expect(
      File('$out/enddata.bin').readAsBytesSync(),
      original.endData,
    );
  });

  test('an export imported back changes nothing', () async {
    final repo = TranslationRepository(db, locale: 'fr');
    final slots = await repo.slots(1);
    await repo.saveTranslation(
      sourceId: slots[1].sourceId,
      text: 'three',
      status: 'translated',
    );
    final out = '${tmp.path}/roundtrip';
    await exportDumpFolder(
      db: db,
      project: project,
      config: config,
      fileId: 1,
      folder: out,
    );
    final n = await importDumpFolder(
      db: db,
      project: project,
      config: config,
      fileId: 1,
      folder: out,
      status: 'translated',
    );
    expect(n, 0);
  });

  test('exportDumpFolder refuses a folder that already holds a dump', () async {
    final d = dumpDir('taken', ['a', 'b', 'a']);
    await expectLater(
      exportDumpFolder(
        db: db,
        project: project,
        config: config,
        fileId: 1,
        folder: d.path,
      ),
      throwsA(isA<TdbError>()),
    );
  });
}
