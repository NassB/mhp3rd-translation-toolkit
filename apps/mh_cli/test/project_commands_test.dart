import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_cli/mh_cli.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

// Builder d'ISO partagé avec mh_iso (aucune donnée du jeu).
import '../../../packages/mh_iso/test/support/iso_builder.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List textFile(List<String> lines) {
  final f = StringTableFile(
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
  );
  return encodeStringTableA(f);
}

/// DATA.BIN synthétique : TOC chiffrée au LBA 0 puis fichiers chiffrés.
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

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mhtk_project');
    final dataBin = buildDataBin([
      textFile(['un\ndeux', 'trois']),
      Uint8List(3000), // tablesCount = 0 : faux positif attendu
      textFile(['quatre']),
    ]);
    final iso = buildIso([
      FakeFile(dataBinIsoPath, dataLba, dataBin.length),
    ]);
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
    project = '${tmp.path}/fr';
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> mhtk(
    Future<int> Function(List<String>, StringSink, StringSink) cmd,
    List<String> args,
  ) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await cmd(args, out, err);
    return (code, '$out', '$err');
  }

  Future<(int, String, String)> init() => mhtk(runInit, [
        '--iso',
        isoPath,
        '--project',
        project,
        '--config',
        config,
      ]);

  Future<(int, String, String)> extract() =>
      mhtk(runExtract, ['--project', project, '--config', config]);

  test('init creates the project and refuses a second one', () async {
    final (code, out, err) = await init();
    expect(code, 0, reason: err);
    expect(out, contains('version:  TEST'));
    expect(out, contains('files:    3 in DATA.BIN'));
    expect(File('$project/project.json').existsSync(), isTrue);
    expect(File('$project/tdb.sqlite').existsSync(), isTrue);
    final p = Project.load(project);
    expect(p.versionId, 'TEST');
    expect(p.locale, 'fr');
    expect(File(p.isoPath).existsSync(), isTrue);

    final again = await init();
    expect(again.$1, 1);
    expect(again.$3, contains('already exists'));
  });

  test('init rejects bad arguments and unknown ISO', () async {
    expect((await mhtk(runInit, [])).$1, 64);
    File(config).writeAsStringSync(
      '- id: OTHER\n  platform: psp\n  iso_md5: ${'a' * 32}\n'
      '  databin_iso_offset: ${dataLba * sectorSize}\n',
    );
    expect((await init()).$1, 1);
    expect(Directory(project).existsSync(), isFalse);
  });

  test('extract imports real text tables only, and is re-runnable', () async {
    await init();
    final first = await extract();
    expect(first.$1, 0, reason: first.$3);
    expect(first.$2, contains('detected: 2'));
    expect(first.$2, contains('imported: 2'));

    final second = await extract();
    expect(second.$1, 0, reason: second.$3);
    expect(second.$2, contains('detected: 2'));
    expect(second.$2, contains('imported: 0'));
    expect(second.$2, contains('already:  2'));
  });

  test('status reports files, strings and translations', () async {
    await init();
    await extract();
    final (code, out, err) = await mhtk(runStatus, ['--project', project]);
    expect(code, 0, reason: err);
    expect(out, contains('files:    2'));
    expect(out, contains('strings:  3'));
    expect(out, contains('untranslated'));
    expect(out, contains('locked        0'));
  });

  test('extract and status fail cleanly without a project', () async {
    final missing = '${tmp.path}/nope';
    expect((await mhtk(runExtract, ['--project', missing])).$1, 1);
    expect((await mhtk(runStatus, ['--project', missing])).$1, 1);
    expect((await mhtk(runExtract, [])).$1, 64);
    expect((await mhtk(runStatus, [])).$1, 64);
  });
}
