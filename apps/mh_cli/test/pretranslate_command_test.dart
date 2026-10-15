import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_cli/mh_cli.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

import '../../../packages/mh_iso/test/support/iso_builder.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

const hello = 'こんにちは。';
const thanks = 'ありがとう\nございます。';
const pen = 'これはペンです。';

const dict = {
  hello: 'Bonjour.',
  thanks: 'Merci\nbeaucoup.',
  pen: "C'est un stylo.",
};

Uint8List textFile(List<String> lines) => encodeStringTableA(
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

/// Client scripté : répond d'après [dict] et enregistre les requêtes.
class FakeClient implements ChatClient {
  FakeClient({this.fail});

  final TranslateError? fail;
  var calls = 0;
  var closed = false;

  @override
  Future<ChatResult> chat({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    JsonSchemaFormat? jsonSchema,
  }) async {
    calls++;
    if (fail != null) throw fail!;
    final req =
        (jsonDecode(messages[1].content) as Map).cast<String, Object?>();
    final items = (req['items']! as List).cast<Map<String, Object?>>();
    return ChatResult(
      content: jsonEncode({
        'items': [
          for (final i in items)
            if (dict.containsKey(i['text']))
              {'id': i['id'], 'text': dict[i['text']]},
        ],
      }),
      finishReason: 'stop',
      promptTokens: 50,
      completionTokens: 10,
    );
  }

  @override
  Future<List<String>> listModels() async => ['model-a', 'embed-b'];
}

void main() {
  const dataLba = 40;
  late Directory tmp;
  late String project;
  late FakeClient client;
  Uri? usedEndpoint;
  String? usedKey;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('mhtk_pretranslate');
    final dataBin = buildDataBin([
      textFile([hello, thanks, 'abc', pen]), // id 1
    ]);
    final iso = buildIso([FakeFile(dataBinIsoPath, dataLba, dataBin.length)]);
    iso.setRange(
      dataLba * sectorSize,
      dataLba * sectorSize + dataBin.length,
      dataBin,
    );
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
    final init = StringBuffer();
    expect(
      await runInit(
        ['--iso', isoPath, '--project', project, '--config', config],
        init,
        init,
      ),
      0,
      reason: '$init',
    );
    final ext = StringBuffer();
    expect(
      await runExtract(['--project', project, '--config', config], ext, ext),
      0,
      reason: '$ext',
    );
    client = FakeClient();
    usedEndpoint = null;
    usedKey = null;
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> pre(
    List<String> args, {
    Map<String, String> env = const {},
    FakeClient? with_,
    CancelToken? cancel,
  }) async {
    final out = StringBuffer();
    final err = StringBuffer();
    final c = with_ ?? client;
    final code = await runPretranslate(
      args,
      out,
      err,
      clientFactory: (e, k) {
        usedEndpoint = e;
        usedKey = k;
        return c;
      },
      env: env,
      cancel: cancel,
    );
    return (code, '$out', '$err');
  }

  List<String> base([List<String> extra = const []]) => [
        '--project',
        project,
        '--file',
        '1',
        '--model',
        'model-a',
        '--endpoint',
        'http://127.0.0.1:1235/v1',
        ...extra,
      ];

  test('--list-models prints the ids from the endpoint', () async {
    final (code, out, _) = await pre(['--list-models']);
    expect(code, 0);
    expect(out, 'model-a\nembed-b\n');
    expect(usedEndpoint.toString(), 'http://localhost:1234/v1'); // défaut
  });

  test('the endpoint and key come from the environment when not given',
      () async {
    await pre(
      ['--list-models'],
      env: {
        'MHTK_LLM_ENDPOINT': 'http://127.0.0.1:1235/v1',
        'MHTK_LLM_API_KEY': 'sk-test',
      },
    );
    expect(usedEndpoint.toString(), 'http://127.0.0.1:1235/v1');
    expect(usedKey, 'sk-test');
  });

  test('--dry-run reports the plan, sends nothing and writes nothing',
      () async {
    final (code, out, _) = await pre(base(['--dry-run']));
    expect(code, 0);
    expect(client.calls, 0);
    expect(out, contains('3 string(s) to translate in 1 batch(es)'));
    expect(out, contains('skipped: 0 empty, 1 without Japanese'));
    expect(out, contains('dry run: nothing was sent'));
    final st = StringBuffer();
    await runStatus(['--project', project], st, st);
    expect(st.toString(), contains('draft         0'));
  });

  test('--dry-run needs neither a model nor a local endpoint', () async {
    final (code, out, _) = await pre([
      '--project',
      project,
      '--file',
      '1',
      '--endpoint',
      'https://api.example.com/v1',
      '--dry-run',
    ]);
    expect(code, 0, reason: out);
    expect(client.calls, 0);
  });

  test('a run saves drafts and prints counts but no game text', () async {
    final (code, out, err) = await pre(base());
    expect(code, 0, reason: err);
    expect(out, contains('progress 3/3: saved 3, failed 0'));
    expect(out, contains('saved 3 draft(s); failed 0'));
    expect(out, contains('tokens: prompt 50, completion 10'));
    for (final text in [hello, thanks, pen, ...dict.values]) {
      expect(out, isNot(contains(text)));
      expect(err, isNot(contains(text)));
    }
    final st = StringBuffer();
    await runStatus(['--project', project], st, st);
    expect(st.toString(), contains('draft         3'));
    // Relancer ne refait rien.
    final again = await pre(base());
    expect(again.$2, contains('nothing to translate'));
    expect(client.calls, 1);
  });

  test('a run writes a JSON Lines log without game text by default', () async {
    final (code, out, err) = await pre(base());
    expect(code, 0, reason: err);
    final logs = Directory('$project/logs').listSync();
    expect(logs, hasLength(1));
    expect(out, contains('log: $project/logs/pretranslate-1-'));
    final text = File(logs.single.path).readAsStringSync();
    expect(text, contains('"type":"run_end"'));
    for (final t in [hello, thanks, pen, ...dict.values]) {
      expect(text, isNot(contains(t)));
    }
  });

  test('--log and --log-text choose the file and add the game text', () async {
    final path = '${tmp.path}/my.jsonl';
    final (code, out, err) = await pre(base(['--log', path, '--log-text']));
    expect(code, 0, reason: err);
    expect(out, contains('log: $path (contains game text: keep it local)'));
    final text = File(path).readAsStringSync();
    expect(text, contains('"includesText":true'));
    expect(Directory('$project/logs').existsSync(), isFalse);
  });

  test('--dry-run writes no log', () async {
    await pre(base(['--dry-run']));
    expect(Directory('$project/logs').existsSync(), isFalse);
  });

  test('--limit restricts the run to the first strings', () async {
    final (code, out, _) = await pre(base(['--limit', '2']));
    expect(code, 0);
    expect(out, contains('saved 2 draft(s)'));
  });

  test('a remote endpoint is refused without --allow-remote', () async {
    final remote = [
      '--project',
      project,
      '--file',
      '1',
      '--model',
      'm',
      '--endpoint',
      'https://api.example.com/v1',
    ];
    final (code, _, err) = await pre(remote);
    expect(code, 64);
    expect(err, contains('not a local endpoint'));
    expect(client.calls, 0);
    expect(usedEndpoint, isNull); // aucun client même créé

    final (ok, out, _) = await pre([...remote, '--allow-remote']);
    expect(ok, 0);
    expect(out, contains('REMOTE'));
    const warning = 'WARNING: the game text is being sent to api.example.com';
    expect(out, contains(warning));
  });

  test('a provider failure stops the run with exit code 1', () async {
    final down = FakeClient(
      fail: const TranslateError(
        TranslateErrorKind.unreachable,
        'cannot reach the server',
      ),
    );
    final (code, _, err) = await pre(base(), with_: down);
    expect(code, 1);
    expect(err, contains('stopped:'));
    expect(err, contains('3 not processed'));
  });

  test('cancelling is reported with exit code 1', () async {
    final cancel = CancelToken()..cancel();
    final (code, out, _) = await pre(base(), cancel: cancel);
    expect(code, 1);
    expect(out, contains('cancelled: 3 string(s) not processed'));
  });

  test('usage and project errors', () async {
    expect((await pre([])).$1, 64);
    final noModel = await pre(['--project', project, '--file', '1']);
    expect(noModel.$1, 64);
    expect((await pre(base(['--limit', '0']))).$1, 64);
    expect((await pre(base(['--bogus']))).$1, 64);
    final badFile =
        await pre(['--project', project, '--file', 'x', '--model', 'm']);
    expect(badFile.$1, 64);
    expect((await pre([...base(), '--endpoint', 'pas une url'])).$1, 64);
    final missing = await pre([
      '--project',
      '${tmp.path}/absent',
      '--file',
      '1',
      '--model',
      'm',
      '--endpoint',
      'http://127.0.0.1:1235/v1',
    ]);
    expect(missing.$1, 1);
    final unknown = await pre(base()..replaceRange(3, 4, ['99']));
    expect(unknown.$1, 1);
    expect(unknown.$3, contains('file not imported'));
  });
}
