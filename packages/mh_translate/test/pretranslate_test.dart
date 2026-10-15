import 'dart:async';
import 'dart:convert';
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
      );

  Future<Map<String, TranslationInfo?>> stored() async => {
        for (final s in await repo.slots(17))
          if (!s.isAlias) s.sourceText: s.translation,
      };

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
    expect(byText[hello]!['max_bytes'], utf8.encode(hello).length);
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
}
