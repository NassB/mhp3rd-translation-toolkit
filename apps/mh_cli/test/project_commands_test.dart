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

  group('import', () {
    late String dump;

    setUp(() {
      dump = '${tmp.path}/dump';
      Directory(dump).createSync();
      File('$dump/filelist.txt').writeAsStringSync(
        '0001.bin 0\nstring_table_0.txt\nstring_table_1.txt\nenddata.bin\n',
      );
      File('$dump/string_table_0.txt')
          .writeAsStringSync('UN<NEWLINE>DEUX\ntrois\n');
    });

    Future<(int, String, String)> import({
      int file = 1,
      String? from,
      List<String> extra = const [],
    }) =>
        mhtk(runImport, [
          '--project',
          project,
          '--from',
          from ?? dump,
          '--file',
          '$file',
          '--config',
          config,
          ...extra,
        ]);

    test('applies a dump folder and shows it in status', () async {
      await init();
      await extract();
      final (code, out, err) = await import();
      expect(code, 0, reason: err);
      expect(out, contains('file 1: 1 translations'));
      final st = await mhtk(runStatus, ['--project', project]);
      expect(st.$2, contains('draft         1'));

      final again = await import(extra: ['--status', 'translated']);
      expect(again.$2, contains('1 translations'));
      expect(
        (await mhtk(runStatus, ['--project', project])).$2,
        contains('translated    1'),
      );
    });

    test('fails cleanly on bad input', () async {
      await init();
      await extract();
      expect((await mhtk(runImport, [])).$1, 64);
      expect((await import(from: '${tmp.path}/absent')).$1, 1);
      expect((await import(file: 2)).$1, 1); // faux positif : non importé
      expect((await import(extra: ['--status', 'bogus'])).$1, 1);
      File('$dump/string_table_0.txt').writeAsStringSync('une seule ligne\n');
      expect((await import()).$1, 1);
    });
  });

  group('budget and build', () {
    late String dump;

    Future<void> translate(String line, {String status = 'translated'}) async {
      dump = '${tmp.path}/dump';
      Directory(dump).createSync(recursive: true);
      File('$dump/string_table_0.txt').writeAsStringSync('$line\ntrois\n');
      final r = await mhtk(runImport, [
        '--project',
        project,
        '--from',
        dump,
        '--file',
        '1',
        '--status',
        status,
        '--config',
        config,
      ]);
      expect(r.$1, 0, reason: r.$3);
    }

    Future<(int, String, String)> budget(
      int file, {
      List<String> extra = const [],
    }) =>
        mhtk(runBudget, [
          '--project',
          project,
          '--file',
          '$file',
          '--config',
          config,
          '--validated',
          '${tmp.path}/none.yaml',
          ...extra,
        ]);

    Future<(int, String, String)> build(
      String out, {
      List<String> extra = const [],
    }) =>
        mhtk(runBuildCommand, [
          '--project',
          project,
          '--target',
          'iso',
          '--out',
          out,
          '--config',
          config,
          '--validated',
          '${tmp.path}/none.yaml',
          ...extra,
        ]);

    setUp(() async {
      await init();
      await extract();
    });

    test('budget reports a file with and without translations', () async {
      await translate('UN<NEWLINE>DEUX');
      final (code, out, err) = await budget(1);
      expect(code, 0, reason: err);
      expect(out, contains('file 1\n'));
      expect(out, contains('status:   ok'));
      expect(out, contains('policy strict'));

      final plain = await budget(3);
      expect(plain.$1, 0, reason: plain.$3);
      expect(plain.$2, contains('no eligible translation'));
      expect(plain.$2, contains('margin:   0 bytes'));
    });

    test('budget rejects bad input and unlisted slot policy', () async {
      expect((await mhtk(runBudget, [])).$1, 64);
      expect((await budget(1, extra: ['--policy', 'bogus'])).$1, 64);
      expect((await budget(99)).$1, 1);
      final slot = await budget(1, extra: ['--policy', 'slot']);
      expect(slot.$1, 1);
      expect(slot.$2, contains('policyNotAllowed'));
    });

    test('build writes a verified copy and leaves the source', () async {
      await translate('UN<NEWLINE>DEUX');
      final before = File(isoPath).readAsBytesSync();
      final outIso = '${tmp.path}/sub/out.iso';
      final (code, out, err) = await build(outIso);
      expect(code, 0, reason: err);
      expect(out, contains('status:   ok'));
      expect(out, contains('file 1: ok'));
      expect(File(outIso).existsSync(), isTrue);
      expect(File(isoPath).readAsBytesSync(), before);

      final again = await build(outIso);
      expect(again.$1, 1);
      expect(again.$3, contains('already exists'));
    });

    test('build with nothing eligible writes no ISO', () async {
      final outIso = '${tmp.path}/none.iso';
      final (code, out, _) = await build(outIso);
      expect(code, 0);
      expect(out, contains('nothing_to_build'));
      expect(File(outIso).existsSync(), isFalse);
    });

    test('build over budget fails and writes no ISO', () async {
      await translate('x' * 3000);
      final outIso = '${tmp.path}/big.iso';
      final (code, out, _) = await build(outIso);
      expect(code, 1);
      expect(out, contains('budget_exceeded'));
      expect(File(outIso).existsSync(), isFalse);
      final b = await budget(1);
      expect(b.$1, 1);
      expect(b.$2, contains('slotOverflow'));
    });

    test('min-status filters drafts; unsupported target is refused', () async {
      await translate('UN<NEWLINE>DEUX', status: 'draft');
      expect(
        (await build('${tmp.path}/a.iso')).$2,
        contains('nothing_to_build'),
      );
      final r =
          await build('${tmp.path}/b.iso', extra: ['--min-status', 'draft']);
      expect(r.$2, contains('status:   ok'));
      final plugin = await mhtk(runBuildCommand, [
        '--project',
        project,
        '--target',
        'plugin',
      ]);
      expect(plugin.$1, 64);
    });
  });

  group('loadValidatedFiles', () {
    test('absent, empty and valid lists', () {
      expect(loadValidatedFiles('${tmp.path}/absent.yaml'), isEmpty);
      final f = File('${tmp.path}/v.yaml')..writeAsStringSync('# x\n[]\n');
      expect(loadValidatedFiles(f.path), isEmpty);
      f.writeAsStringSync('- 17\n- 2813\n');
      expect(loadValidatedFiles(f.path), {17, 2813});
    });

    test('rejects anything but a list of integers', () {
      final f = File('${tmp.path}/v.yaml')..writeAsStringSync('a: 1\n');
      expect(() => loadValidatedFiles(f.path), throwsA(isA<FormatError>()));
      f.writeAsStringSync('- x\n');
      expect(() => loadValidatedFiles(f.path), throwsA(isA<FormatError>()));
    });
  });
}
