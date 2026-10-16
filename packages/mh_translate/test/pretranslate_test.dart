import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

const hello = 'こんにちは。';
const thanks = 'ありがとう\nございます。';
const hunter = 'ハンターは森へ行く。';
const goodbye = 'さようなら';
const water = 'お水をください。';
const pen = 'これはペンです。';

/// Fichier 17 : 0 hello, 1 thanks, 2 alias de 0, 3 vide, 4 sans japonais,
/// 5 hunter, 6 goodbye (translated), 7 water (draft), 8 pen.
StringTableFile sample() => StringTableFile(
      unknownHeader: 0,
      tables: [
        StringTable(
          originalOffsets: const [],
          slots: [
            StringSlot(index: 0, raw: b(hello)),
            StringSlot(index: 1, raw: b(thanks)),
            StringSlot(index: 2, raw: b(hello), aliasOf: 0),
            StringSlot(index: 3, raw: b('')),
            StringSlot(index: 4, raw: b('%d')),
            StringSlot(index: 5, raw: b(hunter)),
            StringSlot(index: 6, raw: b(goodbye)),
            StringSlot(index: 7, raw: b(water)),
            StringSlot(index: 8, raw: b(pen)),
          ],
        ),
      ],
      endData: Uint8List(0),
    );

const dict = {
  hello: 'Bonjour.',
  thanks: 'Merci\nbeaucoup.',
  hunter: 'Le Chasseur va en forêt.',
  water: "De l'eau.",
  pen: "C'est un stylo.",
};

/// Requête telle que le moteur l'a envoyée.
class Req {
  Req(this.json, this.maxTokens);

  final Map<String, Object?> json;
  final int? maxTokens;

  List<Map<String, Object?>> get items =>
      (json['items']! as List).cast<Map<String, Object?>>();

  List<int> get ids => [for (final i in items) i['id']! as int];
}

typedef Responder = FutureOr<String> Function(Req req, int call);

/// Réponse JSON construite d'après [answers] (texte source → traduction).
String answer(Req r, Map<String, String> answers, {Set<int> skip = const {}}) =>
    jsonEncode({
      'items': [
        for (final i in r.items)
          if (!skip.contains(i['id']) && answers.containsKey(i['text']))
            {'id': i['id'], 'text': answers[i['text']]},
      ],
    });

class ScriptedClient implements ChatClient {
  ScriptedClient(this.responder);

  final Responder responder;
  final requests = <Req>[];

  @override
  Future<ChatResult> chat({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    JsonSchemaFormat? jsonSchema,
  }) async {
    final req = Req(
      (jsonDecode(messages[1].content) as Map).cast<String, Object?>(),
      maxTokens,
    );
    requests.add(req);
    final content = await responder(req, requests.length - 1);
    return ChatResult(
      content: content,
      finishReason: 'stop',
      promptTokens: 100,
      completionTokens: 20,
    );
  }

  @override
  Future<List<String>> listModels() async => ['m'];
}

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;
  late GlossaryRepository glossary;
  late Map<String, int> idOf; // source text -> source id

  setUp(() async {
    db = TdbDatabase.openInMemory();
    repo = TranslationRepository(db, locale: 'fr');
    glossary = GlossaryRepository(db, locale: 'fr');
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'T',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: sample(),
    );
    final slots = await repo.slots(17);
    idOf = {
      for (final s in slots)
        if (!s.isAlias) s.sourceText: s.sourceId,
    };
    await repo.saveTranslation(
      sourceId: idOf[goodbye]!,
      text: 'Au revoir (relu)',
      status: 'translated',
    );
    await repo.saveTranslation(
      sourceId: idOf[water]!,
      text: 'Eau (brouillon)',
      status: 'draft',
    );
  });
  tearDown(() => db.close());

  Future<PreTranslateReport> run(
    ScriptedClient client, {
    PreTranslateOptions options = const PreTranslateOptions(),
    CancelToken? cancel,
    void Function(PreTranslateProgress)? onProgress,
    PreTranslateLog? log,
  }) =>
      preTranslateFile(
        repo: repo,
        glossary: glossary,
        client: client,
        model: 'test-model',
        fileId: 17,
        options: options,
        cancel: cancel,
        onProgress: onProgress,
        log: log,
      );

  Future<Map<String, TranslationInfo?>> stored() async => {
        for (final s in await repo.slots(17))
          if (!s.isAlias) s.sourceText: s.translation,
      };

  test('aiDraftsOnly retranslates AI drafts but never a human draft', () async {
    await run(ScriptedClient((r, _) => answer(r, dict))); // 4 brouillons IA
    final client = ScriptedClient(
      (r, _) => answer(r, {for (final e in dict.entries) e.key: '${e.value}!'}),
    );
    final report = await run(
      client,
      options: const PreTranslateOptions(
        includeDrafts: true,
        aiDraftsOnly: true,
      ),
    );
    expect(report.candidates, 4); // hello, thanks, hunter, pen
    expect(report.saved, 4);
    final s = await stored();
    expect(s[water]!.text, 'Eau (brouillon)'); // brouillon humain intact
    expect(s[hello]!.text, endsWith('!'));
  });

  group('journal', () {
    test('by default it holds ids, reasons and sizes but no game text',
        () async {
      final log = MemoryLog();
      // `thanks` perd son saut de ligne aux deux essais : échec final.
      final client = ScriptedClient(
        (r, _) => answer(r, {...dict, thanks: 'Merci beaucoup.'}),
      );
      await run(client, log: log);
      expect(log.ofType('run_start'), hasLength(1));
      expect(log.ofType('run_end').single['failed'], 1);
      expect(log.ofType('run_end').single['failedByReason'], {
        'newlineCount': 1,
      });
      final failed = log.ofType('failed').single;
      expect(failed['reasons'], ['newlineCount']);
      expect(failed['table'], 0);
      expect(failed['slot'], 1);
      expect(log.ofType('rejected'), hasLength(2)); // essai 1 et essai 2
      expect(log.ofType('rejected').first['newlines'], {
        'source': 1,
        'candidate': 0,
      });
      expect(log.ofType('saved'), hasLength(3));
      final all = jsonEncode(log.events);
      for (final text in [...dict.keys, ...dict.values, 'Merci beaucoup.']) {
        expect(all, isNot(contains(text)));
      }
    });

    test('includeText adds the source and the rejected candidate', () async {
      final log = MemoryLog(includeText: true);
      final client = ScriptedClient(
        (r, _) => answer(r, {...dict, thanks: 'Merci beaucoup.'}),
      );
      await run(client, log: log);
      final rej = log.ofType('rejected').first;
      expect(rej['source'], thanks);
      expect(rej['candidate'], 'Merci beaucoup.');
      expect(log.ofType('run_start').single['includesText'], isTrue);
    });

    test('a string fixed by the retry is logged as rejected then saved',
        () async {
      final log = MemoryLog();
      final client = ScriptedClient(
        (r, call) => answer(
          r,
          {...dict, if (call == 0) thanks: 'Merci beaucoup.'},
        ),
      );
      await run(client, log: log);
      expect(log.ofType('failed'), isEmpty);
      expect(log.ofType('rejected').single['attempt'], 1);
      final fixed = [
        for (final e in log.ofType('saved'))
          if (e['attempt'] == 2) e,
      ];
      expect(fixed.single['slot'], 1);
      expect(
        [for (final e in log.ofType('request')) e['phase']],
        ['first', 'retry'],
      );
    });

    test('a missing answer and an unusable response are explained', () async {
      final log = MemoryLog();
      final client = ScriptedClient(
        (r, _) => answer(r, dict, skip: {r.ids.first}),
      );
      await run(client, log: log);
      final req = log.ofType('request').first;
      expect(req['asked'], 4);
      expect(req['received'], 3);
      expect(req['missing'], 1);
      expect(req['finishReason'], 'stop');
      expect(log.ofType('failed').single['reasons'], ['missing']);
    });

    test('an unusable response is logged for both attempts', () async {
      final log2 = MemoryLog();
      await run(ScriptedClient((r, _) => 'not json at all'), log: log2);
      expect(log2.ofType('request').map((e) => e['error']), [
        'invalidResponse',
        'invalidResponse',
      ]);
      expect(log2.ofType('failed'), hasLength(4));
    });

    test('a provider failure is logged as stopped', () async {
      final log = MemoryLog();
      await run(
        ScriptedClient((r, _) {
          throw const TranslateError(TranslateErrorKind.timeout, 'late');
        }),
        log: log,
      );
      expect(log.ofType('stopped').single['error'], 'timeout');
      expect(log.ofType('run_end').single['stoppedBy'], 'timeout');
    });

    test('the file log writes one JSON object per line', () async {
      final dir = Directory.systemTemp.createTempSync('mhlog');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path =
          defaultLogPath(dir.path, 17, DateTime.utc(2026, 10, 16, 1, 2, 3));
      expect(path, '${dir.path}/logs/pretranslate-17-20261016-010203.jsonl');
      await run(
        ScriptedClient((r, _) => answer(r, dict)),
        log: JsonlFileLog(path),
      );
      final lines = File(path).readAsLinesSync();
      final types = [
        for (final l in lines) (jsonDecode(l) as Map)['type'],
      ];
      expect(types.first, 'run_start');
      expect(types.last, 'run_end');
      expect(types.where((t) => t == 'saved'), hasLength(4));
    });
  });

  test('translates the candidates as drafts and leaves the rest alone',
      () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final report = await run(client);

    expect(report.candidates, 4); // hello, thanks, hunter, pen
    expect(report.saved, 4);
    expect(report.failed, isEmpty);
    expect(report.clean, isTrue);
    expect(report.skippedEmpty, 1);
    expect(report.skippedNoJapanese, 1);
    expect(report.batches, 1);
    expect((report.promptTokens, report.completionTokens), (100, 20));

    final s = await stored();
    for (final src in [hello, thanks, hunter, pen]) {
      expect(s[src]!.status, 'draft', reason: src);
      expect(s[src]!.authorId, 'ai:test-model');
    }
    expect(s[hello]!.text, 'Bonjour.');
    expect(s[thanks]!.text, 'Merci\nbeaucoup.');
    // Intact : relue, brouillon existant, vide, sans japonais.
    expect(s[goodbye]!.text, 'Au revoir (relu)');
    expect(s[goodbye]!.status, 'translated');
    expect(s[water]!.text, 'Eau (brouillon)');
    expect(s['%d'], isNull);
    // L'historique reçoit la première révision.
    expect((await repo.history(idOf[hello]!)).single.revision, 1);
  });

  test('a rerun finds nothing to do and never calls the model', () async {
    await run(ScriptedClient((r, _) => answer(r, dict)));
    final again = ScriptedClient((r, _) => fail('must not be called'));
    final report = await run(again);
    expect(report.candidates, 0);
    expect(report.saved, 0);
    expect(again.requests, isEmpty);
    expect(report.clean, isTrue);
  });

  test('includeDrafts retranslates drafts but never translated or better',
      () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final report = await run(
      client,
      options: const PreTranslateOptions(includeDrafts: true),
    );
    expect(report.candidates, 5); // + water
    final s = await stored();
    expect(s[water]!.text, "De l'eau.");
    expect(s[water]!.revision, 2);
    expect(s[goodbye]!.text, 'Au revoir (relu)');
    expect(s[goodbye]!.status, 'translated');
  });

  test('the prompt carries byte limits, neighbours and matching glossary',
      () async {
    await glossary.add(
      sourceTerm: 'ハンター',
      targetTerm: 'Chasseur',
      mandatory: true,
    );
    await glossary.add(sourceTerm: 'アイルー', targetTerm: 'Felyne');
    final client = ScriptedClient((r, _) => answer(r, dict));
    await run(client);
    final req = client.requests.single;
    final byText = {for (final i in req.items) i['text']: i};
    // max(24, ceil(18 × 2,5)) : plafond large, l'enveloppe du fichier décide.
    expect(byText[hello]!['max_bytes'], 45);
    expect(req.json['glossary'], [
      {'source': 'ハンター', 'target': 'Chasseur', 'mandatory': true},
    ]);
    expect(req.json.containsKey('context_before'), isFalse); // 1er slot
    expect(req.json.containsKey('context_after'), isFalse); // dernier slot
  });

  test('a newline mismatch is retried once with a fix for that unit only',
      () async {
    final client = ScriptedClient((r, call) {
      if (call == 0) {
        return answer(r, {...dict, thanks: 'Merci beaucoup.'}); // sans saut
      }
      return answer(r, dict);
    });
    final report = await run(client);
    expect(report.saved, 4);
    expect(client.requests, hasLength(2));
    final retry = client.requests[1];
    expect(retry.ids, [idOf[thanks]]);
    expect(retry.items.single['fix'], contains('1 saut(s) de ligne'));
    expect((await stored())[thanks]!.text, 'Merci\nbeaucoup.');
  });

  test('a missing mandatory term triggers the same single retry', () async {
    await glossary.add(
      sourceTerm: 'ハンター',
      targetTerm: 'Chasseur',
      mandatory: true,
    );
    final client = ScriptedClient((r, call) {
      return call == 0
          ? answer(r, {...dict, hunter: 'Le joueur va en forêt.'})
          : answer(r, dict);
    });
    final report = await run(client);
    expect(report.saved, 4);
    expect(client.requests[1].items.single['fix'], contains('« Chasseur »'));
  });

  test('invisible characters trigger a retry, then a dedicated refusal',
      () async {
    final retried = ScriptedClient((r, call) {
      return call == 0
          ? answer(r, {...dict, hunter: 'Le chasseur\u200B va\ten forêt.'})
          : answer(r, dict);
    });
    final ok = await run(retried);
    expect(ok.saved, 4);
    expect(
      retried.requests[1].items.single['fix'],
      allOf(contains('U+0009'), contains('U+200B')),
    );
    expect((await stored())[hunter]!.text, dict[hunter]);
  });

  test('invisible characters returned twice are refused', () async {
    final client = ScriptedClient(
      (r, _) => answer(r, {...dict, hunter: 'Le chasseur\u200B va en forêt.'}),
    );
    final report = await run(client);
    expect(report.failed.single.reasons, {FailureReason.invisibleChar});
    expect((await stored())[hunter], isNull);
  });

  test('a string failing twice is left untouched; the others are saved',
      () async {
    final client = ScriptedClient(
      (r, _) => answer(r, {...dict, thanks: 'Merci beaucoup.'}),
    );
    final report = await run(client);
    expect(client.requests, hasLength(2)); // un seul nouvel essai
    expect(report.saved, 3);
    expect(report.failed.single.sourceId, idOf[thanks]);
    expect(report.failed.single.reasons, {FailureReason.newlineCount});
    expect(report.clean, isFalse);
    expect((await stored())[thanks], isNull);
  });

  test('over-budget text is retried then refused', () async {
    final tooLong = 'x' * 200;
    final client =
        ScriptedClient((r, _) => answer(r, {...dict, hello: tooLong}));
    final report = await run(client);
    expect(report.failed.single.reasons, {FailureReason.overBudget});
    expect(client.requests[1].items.single['fix'], contains('octets'));
    expect((await stored())[hello], isNull);
    expect(report.saved, 3);
  });

  test('missing and unexpected items: missing ones are retried', () async {
    final client = ScriptedClient((r, call) {
      if (call == 0) {
        final partial = jsonDecode(answer(r, dict, skip: {idOf[pen]!}))
            as Map<String, Object?>;
        (partial['items']! as List).add({'id': 99999, 'text': 'intrus'});
        return jsonEncode(partial);
      }
      return answer(r, dict);
    });
    final report = await run(client);
    expect(report.saved, 4);
    expect(client.requests[1].ids, [idOf[pen]]);
  });

  test('unusable output counts as nothing received, then is retried', () async {
    final client = ScriptedClient(
      (r, call) => call == 0 ? 'désolé, impossible' : answer(r, dict),
    );
    final report = await run(client);
    expect(report.saved, 4);
    expect(client.requests, hasLength(2));
    expect(
      client.requests[1].maxTokens,
      greaterThan(client.requests[0].maxTokens!),
    );
  });

  test('batches follow maxUnits and neighbours span the previous batch',
      () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final report = await run(
      client,
      options: const PreTranslateOptions(maxUnits: 2),
    );
    expect(report.batches, 2);
    expect(client.requests[0].ids, [idOf[hello], idOf[thanks]]);
    expect(client.requests[1].ids, [idOf[hunter], idOf[pen]]);
    expect(client.requests[1].json['context_before'], contains(thanks));
  });

  test('progress is reported after every batch', () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final seen = <PreTranslateProgress>[];
    await run(
      client,
      options: const PreTranslateOptions(maxUnits: 2),
      onProgress: seen.add,
    );
    expect(seen.map((p) => (p.processed, p.total, p.saved, p.failed)), [
      (2, 4, 2, 0),
      (4, 4, 4, 0),
    ]);
  });

  test('cancelling between batches keeps what was saved', () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final cancel = CancelToken();
    final report = await run(
      client,
      options: const PreTranslateOptions(maxUnits: 2),
      cancel: cancel,
      onProgress: (_) => cancel.cancel(),
    );
    expect(report.cancelled, isTrue);
    expect(report.saved, 2);
    expect(report.unprocessed, 2);
    expect(client.requests, hasLength(1));
    expect(report.clean, isFalse);
    expect((await stored())[hunter], isNull);
  });

  test('a provider failure stops the run and reports it, keeping progress',
      () async {
    final client = ScriptedClient((r, call) {
      if (call == 0) return answer(r, dict);
      throw const TranslateError(
        TranslateErrorKind.unreachable,
        'cannot reach the server',
      );
    });
    final report = await run(
      client,
      options: const PreTranslateOptions(maxUnits: 2),
    );
    expect(report.stoppedBy?.kind, TranslateErrorKind.unreachable);
    expect(report.saved, 2);
    expect(report.unprocessed, 2);
    expect(report.clean, isFalse);
  });

  test('a row changed during the call is a conflict, never overwritten',
      () async {
    final client = ScriptedClient((r, _) async {
      await repo.saveTranslation(
        sourceId: idOf[hello]!,
        text: 'Salut (autre traducteur)',
        status: 'draft',
      );
      return answer(r, dict);
    });
    final report = await run(client);
    expect(report.conflicts, 1);
    expect(report.saved, 3);
    expect((await stored())[hello]!.text, 'Salut (autre traducteur)');
  });

  test('edge whitespace the source lacks is trimmed, other lint is a warning',
      () async {
    final client = ScriptedClient(
      (r, _) => answer(r, {...dict, hello: '  Bonjour.\n'}),
    );
    final report = await run(client);
    expect((await stored())[hello]!.text, 'Bonjour.');
    expect(report.failed, isEmpty);
  });

  test('the report holds no game text', () async {
    final client = ScriptedClient(
      (r, _) => answer(r, {...dict, thanks: 'Merci beaucoup.'}),
    );
    final report = await run(client);
    final dump = [
      '${report.failed.map((f) => '${f.sourceId} ${f.reasons}')}',
      '${report.candidates} ${report.saved} ${report.warnings}',
    ].join(' ');
    for (final text in [hello, thanks, hunter, pen, 'Bonjour']) {
      expect(dump, isNot(contains(text)));
    }
  });

  test('limit keeps the first strings of the file only', () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final report = await run(
      client,
      options: const PreTranslateOptions(limit: 2),
    );
    expect(report.candidates, 2);
    final s = await stored();
    expect(s[hello], isNotNull);
    expect(s[thanks], isNotNull);
    expect(s[hunter], isNull);
    expect(s[pen], isNull);
  });

  test('the plan counts what a run would do and sends nothing', () async {
    const options = PreTranslateOptions(maxUnits: 2);
    final plan = await planPreTranslation(
      repo: repo,
      fileId: 17,
      options: options,
    );
    expect(plan.candidates, 4);
    expect(plan.batches, 2);
    expect(plan.skippedEmpty, 1);
    expect(plan.skippedNoJapanese, 1);
    expect(plan.estimatedPromptTokens, greaterThan(2 * 350));

    final withDrafts = await planPreTranslation(
      repo: repo,
      fileId: 17,
      options: const PreTranslateOptions(includeDrafts: true),
    );
    expect(withDrafts.candidates, 5);
    // Aucune écriture : rien n'a été traduit.
    expect((await stored())[hello], isNull);
  });

  // Réponses longues (octets) : hello 40, thanks 80, hunter 70, pen 55.
  final longDict = {
    hello: 'Bonjour a tous, tres chers amis de la chasse',
    thanks: 'Merci beaucoup\npour votre aide precieuse et votre patience !',
    hunter: 'Le Chasseur part explorer la grande foret ce matin',
    pen: 'Ceci est un stylo tout a fait ordinaire, merci',
  };

  test('the file starts with a margin counted from existing translations',
      () async {
    final plan = await planPreTranslation(repo: repo, fileId: 17);
    // goodbye +1 octet, water -9 octets : marge de 8.
    expect(plan.budgetMarginBytes, 8);
    final report = await run(ScriptedClient((r, _) => answer(r, dict)));
    expect(report.startDeltaBytes, -8);
    expect(report.endDeltaBytes, -51);
    expect(report.withinBudget, isTrue);
    expect(report.shortened, 0);
    expect(report.overBudgetBytes, 0);
  });

  test('a short string may exceed its source while the file keeps room',
      () async {
    final client = ScriptedClient(
      (r, _) =>
          answer(r, {...dict, hello: 'Bonjour a tous, tres chers amis!!'}),
    );
    final report = await run(client);
    // 33 octets pour une source de 18 : refusé avec l'ancien plafond.
    expect(report.saved, 4);
    expect(report.failed, isEmpty);
    expect(report.withinBudget, isTrue);
    expect(client.requests, hasLength(1)); // pas de passe de raccourcissement
    expect((await stored())[hello]!.text, 'Bonjour a tous, tres chers amis!!');
  });

  test(
      'when the file would exceed its original the biggest growth is shortened',
      () async {
    int len(String s) => utf8.encode(s).length;
    // Ordre attendu : croissance décroissante (octets de la réponse longue
    // moins octets de la source) ; arrêt dès que le total tient.
    final order = [hello, thanks, hunter, pen]..sort(
        (a, c) => (len(longDict[c]!) - len(c)).compareTo(
          len(longDict[a]!) - len(a),
        ),
      );
    var delta = -8 +
        [for (final s in order) len(longDict[s]!) - len(s)]
            .fold(0, (a, c) => a + c);
    expect(delta, greaterThan(0), reason: 'le scénario doit dépasser');
    var expectedShortened = 0;
    for (final s in order) {
      if (delta <= 0) break;
      delta += len(dict[s]!) - len(longDict[s]!);
      expectedShortened++;
    }

    final client = ScriptedClient((r, call) {
      return call == 0 ? answer(r, longDict) : answer(r, dict);
    });
    final report = await run(client);
    expect(client.requests, hasLength(2));
    final shorten = client.requests[1];
    expect(shorten.ids, [for (final s in order) idOf[s]]);
    final first = shorten.items.first;
    expect(first['fix'], contains('budget d’octets du fichier'));
    expect(
      first['max_bytes'],
      max(len(order.first), 16),
    ); // octets de la source

    expect(report.shortened, expectedShortened);
    expect(report.withinBudget, isTrue);
    expect(report.endDeltaBytes, delta);
    expect(report.clean, isTrue);
    final s = await stored();
    for (var i = 0; i < order.length; i++) {
      final done = i < expectedShortened;
      expect(s[order[i]]!.text, done ? dict[order[i]] : longDict[order[i]]);
      expect(s[order[i]]!.revision, done ? 2 : 1);
    }
  });

  test('an unfixable overshoot is reported, never hidden', () async {
    final client = ScriptedClient((r, _) => answer(r, longDict));
    final report = await run(client);
    expect(client.requests, hasLength(2)); // une passe, sans effet
    expect(report.shortened, 0);
    expect(report.withinBudget, isFalse);
    expect(report.overBudgetBytes, greaterThan(0));
    expect(report.clean, isFalse);
    expect(report.saved, 4); // les brouillons restent enregistrés
  });

  test('enforceFileBudget off keeps a single pass', () async {
    final client = ScriptedClient((r, _) => answer(r, longDict));
    final report = await run(
      client,
      options: const PreTranslateOptions(enforceFileBudget: false),
    );
    expect(client.requests, hasLength(1));
    expect(report.withinBudget, isFalse);
  });

  test('a provider failure during the shortening pass is reported', () async {
    final client = ScriptedClient((r, call) {
      if (call == 0) return answer(r, longDict);
      throw const TranslateError(TranslateErrorKind.timeout, 'late');
    });
    final report = await run(client);
    expect(report.stoppedBy?.kind, TranslateErrorKind.timeout);
    expect(report.saved, 4);
    expect(report.withinBudget, isFalse);
  });

  test('the system prompt tells the model about the file byte budget',
      () async {
    final messages = buildMessages(
      Batch([const TranslationUnit(id: 1, source: 'あ', maxBytes: 24)], 0),
    );
    expect(messages[0].content, contains('budget d\'octets total'));
    expect(messages[0].content, contains('comparable'));
  });

  test('onlySourceIds restricts the run; drafts need includeDrafts', () async {
    final client = ScriptedClient((r, _) => answer(r, dict));
    final report = await run(
      client,
      options: PreTranslateOptions(onlySourceIds: {idOf[pen]!, idOf[water]!}),
    );
    // water est un brouillon : exclu sans includeDrafts ; pen est retenue.
    expect(report.candidates, 1);
    expect(client.requests.single.ids, [idOf[pen]]);
    final s = await stored();
    expect(s[pen]!.text, "C'est un stylo.");
    expect(s[hello], isNull); // le reste du fichier n'est pas touché
    expect(s[water]!.text, 'Eau (brouillon)');

    final again = ScriptedClient((r, _) => answer(r, dict));
    final withDraft = await run(
      again,
      options: PreTranslateOptions(
        onlySourceIds: {idOf[water]!},
        includeDrafts: true,
      ),
    );
    expect(withDraft.candidates, 1);
    expect((await stored())[water]!.text, "De l'eau.");
  });
}
