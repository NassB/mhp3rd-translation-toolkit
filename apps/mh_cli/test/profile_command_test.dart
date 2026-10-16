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

import '../../../packages/mh_iso/test/support/iso_builder.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List textFile() => encodeStringTableA(
      StringTableFile(
        unknownHeader: 8,
        tables: [
          StringTable(
            originalOffsets: const [],
            slots: [
              StringSlot(index: 0, raw: b('こんにちは')),
              StringSlot(index: 1, raw: b('ありがとう')),
            ],
          ),
          StringTable(
            originalOffsets: const [],
            slots: [StringSlot(index: 0, raw: b('さようなら'))],
          ),
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
  late String project;
  late String profiles;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mhtk_profile');
    final dataBin = buildDataBin([textFile()]);
    final iso = buildIso([FakeFile(dataBinIsoPath, dataLba, dataBin.length)]);
    final start = dataLba * sectorSize;
    iso.setRange(start, start + dataBin.length, dataBin);
    final isoPath = '${tmp.path}/game.iso';
    File(isoPath).writeAsBytesSync(iso);
    final config = '${tmp.path}/versions.yaml';
    File(config).writeAsStringSync(
      '- id: TEST\n'
      '  platform: psp\n'
      '  iso_md5: ${md5.convert(iso)}\n'
      '  databin_iso_offset: ${dataLba * sectorSize}\n',
    );
    project = '${tmp.path}/fr';
    profiles = '${tmp.path}/profiles.yaml';
    File(profiles).writeAsStringSync(
      'profiles:\n'
      '  menu_label: {max_lines: 1}\n'
      '  plain: {}\n'
      '  dialogue: {max_px: 0, max_lines: 3, paginated: true}\n',
    );
    final sink = StringBuffer();
    expect(
      await runInit(
        ['--iso', isoPath, '--project', project, '--config', config],
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

  Future<(int, String, String)> profile(List<String> args) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final code = await runProfile(args, out, err);
    return (code, '$out', '$err');
  }

  test('list prints the profiles, saying what is unmeasured', () async {
    final (code, out, _) = await profile(['list', '--profiles', profiles]);
    expect(code, 0);
    expect(
      out,
      contains(
        'plain: max_px unmeasured, max_lines unmeasured, font unmeasured '
        '(no limit: no warning)',
      ),
    );
    expect(out, contains('dialogue: max_px unmeasured, max_lines 3'));
    expect(out, contains('paginated'));
  });

  test('the repository profiles list without a file argument', () async {
    // Lancé depuis le dossier du paquet : le fichier du dépôt est plus haut.
    final (code, out, _) = await profile([
      'list',
      '--profiles',
      '../../config/profiles.yaml',
    ]);
    expect(code, 0);
    expect(out, contains('menu_label'));
  });

  test('set and show: file default, then a table override', () async {
    final base = ['--project', project, '--file', '1', '--profiles', profiles];
    var (code, out, err) =
        await profile(['set', ...base, '--profile', 'dialogue']);
    expect(code, 0, reason: err);
    expect(out, contains('file 1: default profile set to dialogue'));

    (code, out, err) = await profile(
      ['set', ...base, '--table', '1', '--profile', 'menu_label'],
    );
    expect(code, 0, reason: err);
    expect(out, contains('file 1 table 1: 1 string(s) set to menu_label'));

    (code, out, _) = await profile(['show', '--project', project]);
    expect(out, contains('file 1:'));
    expect(out, contains('dialogue: 2'));
    expect(out, contains('menu_label: 1'));

    (code, out, _) = await profile(['set', ...base, '--clear']);
    expect(out, contains('default profile cleared'));
    (code, out, _) =
        await profile(['show', '--project', project, '--file', '1']);
    expect(out, contains('(none): 2'));
    expect(out, contains('menu_label: 1'));
  });

  test('unknown profile, unknown file and bad usage', () async {
    final base = ['--project', project, '--profiles', profiles];
    var (code, _, err) = await profile(
      ['set', ...base, '--file', '1', '--profile', 'nope'],
    );
    expect(code, 1);
    expect(err, contains('unknown profile'));
    (code, _, err) = await profile(
      ['set', ...base, '--file', '99', '--profile', 'dialogue'],
    );
    expect(code, 1);
    expect(err, contains('not imported'));
    for (final args in [
      <String>[],
      ['bogus'],
      ['set', ...base, '--file', '1'], // neither --profile nor --clear
      ['set', ...base, '--file', '1', '--profile', 'dialogue', '--clear'],
      ['set', ...base, '--file', 'x', '--profile', 'dialogue'],
      ['set', ...base, '--profile', 'dialogue'], // no file
      ['show'],
    ]) {
      expect((await profile(args)).$1, 64, reason: '$args');
    }
  });
}
