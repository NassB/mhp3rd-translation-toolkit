import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_cli/mh_cli.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

import '../../../packages/mh_iso/test/support/iso_builder.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

const lines = [
  'こんにちは、世界のみなさん。',
  '~C02ありがとう\nございます。~C00',
  'ア',
];

Uint8List textFile() => encodeStringTableA(
      StringTableFile(
        unknownHeader: 8,
        tables: [
          StringTable(
            originalOffsets: const [],
            slots: [
              for (var i = 0; i < lines.length; i++)
                StringSlot(index: i, raw: b(lines[i])),
            ],
          ),
          null,
        ],
        endData: Uint8List(0),
      ),
    );

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
  late String isoPath;
  late String config;
  late String project;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mhtk_calibrate');
    final dataBin = buildDataBin([textFile()]);
    final iso = buildIso([FakeFile(dataBinIsoPath, dataLba, dataBin.length)]);
    final start = dataLba * sectorSize;
    iso.setRange(start, start + dataBin.length, dataBin);
    isoPath = '${tmp.path}/game.iso';
    File(isoPath).writeAsBytesSync(iso);
    config = '${tmp.path}/versions.yaml';
    File(config).writeAsStringSync(
      '- id: TEST\n'
      '  platform: psp\n'
      '  iso_md5: ${md5.convert(iso)}\n'
      '  databin_iso_offset: ${dataLba * sectorSize}\n',
    );
    project = '${tmp.path}/calib';
    final sink = StringBuffer();
    expect(
      await runInit(
        [
          '--iso',
          isoPath,
          '--project',
          project,
          '--locale',
          'calib',
          '--config',
          config,
        ],
        sink,
        sink,
      ),
      0,
      reason: '$sink',
    );
    expect(
      await runExtract(['--project', project, '--config', config], sink, sink),
      0,
      reason: '$sink',
    );
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> calibrate(List<String> args) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runCalibrate(args, out, err);
    return (code, '$out', '$err');
  }

  test('fills the file with test strings and writes the report', () async {
    final (code, out, err) = await calibrate(
      ['--project', project, '--file', '1'],
    );
    expect(code, 0, reason: err);
    expect(out, contains('2 string(s) replaced'));
    expect(
      out,
      contains('mhtk build --project $project --out out/MHP3.calib.iso'),
    );
    expect(out, isNot(contains('note:')));
    final md = File('$project/CALIBRATION.md').readAsStringSync();
    expect(md, contains('| [#1] | 0.0 | narrow |'));
    expect(md, contains('| [#2] | 0.1 | wide |'));
    expect(RegExp(r'[぀-ヿ㐀-鿿]').hasMatch(md), isFalse);
    for (final text in [out, err]) {
      expect(RegExp(r'[぀-ヿ㐀-鿿]').hasMatch(text), isFalse);
    }
  });

  test('the calibration build fits the original and is verified', () async {
    await calibrate(['--project', project, '--file', '1']);
    final outIso = '${tmp.path}/out/calib.iso';
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runBuildCommand(
      ['--project', project, '--out', outIso, '--config', config],
      out,
      err,
    );
    expect(code, 0, reason: '$out $err');
    expect(out.toString(), contains('status:   ok'));
    expect(File(outIso).lengthSync(), File(isoPath).lengthSync());
  });

  test('refuses a file that already holds real translations', () async {
    final db = TdbDatabase.openFile(Project.load(project).dbPath);
    final repo = TranslationRepository(db, locale: 'calib');
    final s = (await repo.slots(1)).first;
    await repo.saveTranslation(
      sourceId: s.sourceId,
      text: 'Bonjour.',
      status: 'translated',
    );
    await db.close();
    final (code, _, err) = await calibrate(
      ['--project', project, '--file', '1'],
    );
    expect(code, 1);
    expect(err, contains('not calibration text'));
    final forced =
        await calibrate(['--project', project, '--file', '1', '--force']);
    expect(forced.$1, 0);
  });

  test('bad arguments and unknown files', () async {
    expect((await calibrate([])).$1, 64);
    expect((await calibrate(['--project', project])).$1, 64);
    expect((await calibrate(['--project', project, '--file', 'x'])).$1, 64);
    expect((await calibrate(['--project', project, '--file', '1,x'])).$1, 64);
    final mixed = await calibrate(['--project', project, '--file', '1,99']);
    expect(mixed.$1, 1);
    final db = TdbDatabase.openFile(Project.load(project).dbPath);
    final slots = await TranslationRepository(db, locale: 'calib').slots(1);
    await db.close();
    expect(
      slots.every((s) => s.translation == null),
      isTrue,
      reason: 'an unknown file id must not leave a half-done calibration',
    );
    final (code, _, err) = await calibrate(
      ['--project', project, '--file', '99'],
    );
    expect(code, 1);
    expect(err, contains('not imported'));
  });
}
