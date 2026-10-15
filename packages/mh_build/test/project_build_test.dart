import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

import '../../mh_iso/test/support/iso_builder.dart';
import 'support/build_fixtures.dart';

/// DATA.BIN synthétique : TOC chiffrée au LBA 0, puis [files] chiffrés.
Uint8List buildDataBin(List<Uint8List> files) {
  const cipher = DataCipher();
  final toc = alignUp((files.length + 1) * 4, sectorSize) ~/ sectorSize;
  final starts = <int>[toc];
  for (final f in files) {
    starts.add(starts.last + alignUp(f.length, sectorSize) ~/ sectorSize);
  }
  final tocPlain = ByteWriter();
  starts.forEach(tocPlain.u32);
  tocPlain.padTo(toc * sectorSize);
  final w = ByteWriter()..bytes(cipher.encrypt(tocPlain.toBytes(), 0));
  for (var i = 0; i < files.length; i++) {
    final padded = ByteWriter()
      ..bytes(files[i])
      ..padTo(sectorSize);
    w.bytes(cipher.encrypt(padded.toBytes(), starts[i]));
  }
  return w.toBytes();
}

void main() {
  const dataLba = 40;
  late Directory tmp;
  late String config;
  late String isoPath;
  late Project project;
  late Uint8List srcBytes;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mh_project_build');
    final original = model();
    final plain = slotBytesOf(original);
    final dataBin = buildDataBin([plain]);
    srcBytes = buildIso([FakeFile(dataBinIsoPath, dataLba, dataBin.length)]);
    srcBytes.setRange(
      dataLba * sectorSize,
      dataLba * sectorSize + dataBin.length,
      dataBin,
    );
    isoPath = '${tmp.path}/game.iso';
    File(isoPath).writeAsBytesSync(srcBytes);
    config = '${tmp.path}/versions.yaml';
    File(config).writeAsStringSync(
      '- id: TEST\n'
      '  platform: psp\n'
      '  iso_md5: ${md5.convert(srcBytes)}\n'
      '  databin_iso_offset: ${dataLba * sectorSize}\n',
    );
    project = Project(
      dir: tmp.path,
      isoPath: isoPath,
      versionId: 'TEST',
      locale: 'fr',
    );
    final db = TdbDatabase.openFile(project.dbPath);
    await importSourceFile(
      db,
      fileId: 1,
      versionId: 'TEST',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: original,
    );
    await db.close();
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> translate(String text) async {
    final db = TdbDatabase.openFile(project.dbPath);
    final repo = TranslationRepository(db, locale: 'fr');
    final first = (await repo.slots(1)).first;
    await repo.saveTranslation(
      sourceId: first.sourceId,
      text: text,
      status: 'translated',
    );
    await db.close();
  }

  Future<BuildSummary> build(String name, {BudgetPolicy? policy}) =>
      runProjectBuild(
        project,
        config: config,
        outPath: '${tmp.path}/out/$name.iso',
        policy: policy ?? BudgetPolicy.strict,
        validatedFiles: '${tmp.path}/none.yaml',
      );

  test('builds a verified ISO copy and returns a light summary', () async {
    await translate('UN');
    final s = await build('ok');
    expect(s.ok, isTrue);
    expect(s.status, BuildStatus.ok);
    expect(s.buildId, 1);
    expect(s.tdbRevision, 1);
    expect(s.files.single.fileId, 1);
    expect(s.files.single.status, BudgetStatus.ok);
    expect(s.verifyErrors, isEmpty);
    expect(File(s.outPath).existsSync(), isTrue);
    expect(File(isoPath).readAsBytesSync(), srcBytes); // source intacte
    expect(s.reportJson, contains('"status":"ok"'));

    final db = TdbDatabase.openFile(project.dbPath);
    final rows = await recentBuilds(db);
    await db.close();
    expect(rows.single.status, 'ok');
  });

  test('nothing to build and budget failures write no ISO', () async {
    final none = await build('none');
    expect(none.status, BuildStatus.nothingToBuild);
    expect(File(none.outPath).existsSync(), isFalse);

    await translate('x' * 3000);
    final over = await build('over');
    expect(over.status, BuildStatus.budgetExceeded);
    expect(File(over.outPath).existsSync(), isFalse);
    expect(over.files.single.status, BudgetStatus.slotOverflow);
  });

  test('the slot policy needs the whitelist', () async {
    await translate('UN');
    final s = await build('slot', policy: BudgetPolicy.slot);
    expect(s.status, BuildStatus.budgetExceeded);
    expect(s.files.single.status, BudgetStatus.policyNotAllowed);
  });

  test('recentBuilds returns the newest first and honours the limit', () async {
    await translate('UN');
    await build('a');
    await build('none-again'); // même contenu : nouvelle ligne `build`
    final db = TdbDatabase.openFile(project.dbPath);
    final rows = await recentBuilds(db, limit: 1);
    await db.close();
    expect(rows, hasLength(1));
    expect(rows.single.id, 2);
  });

  test('loadValidatedFiles now lives in mh_build', () {
    expect(loadValidatedFiles('${tmp.path}/absent.yaml'), isEmpty);
    final f = File('${tmp.path}/v.yaml')..writeAsStringSync('- 17\n- 2813\n');
    expect(loadValidatedFiles(f.path), {17, 2813});
  });
}
