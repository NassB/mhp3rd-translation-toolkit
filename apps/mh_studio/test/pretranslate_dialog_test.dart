import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_studio/features/ai/application/ai_providers.dart';
import 'package:mh_studio/features/ai/presentation/pretranslate_dialog.dart';
import 'package:mh_studio/features/editor/presentation/file_editor_page.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_studio/features/glossary/application/glossary_providers.dart';
import 'package:mh_studio/features/memory/application/memory_providers.dart';
import 'package:mh_studio/features/project/application/project_providers.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

const hello = 'こんにちは。';
const thanks = 'ありがとう\nございます。';
const hunter = 'ハンターは森へ行く。';
const dict = {
  hello: 'Bonjour.',
  thanks: 'Merci\nbeaucoup.',
  hunter: 'Le Chasseur va en forêt.',
};

const project = Project(
  dir: 'p',
  isoPath: 'x.iso',
  versionId: 'TEST',
  locale: 'fr',
);

const baseBudget = FileBudget(
  fileId: 17,
  origBytes: 4096,
  slotBytes: 4096,
  rebuiltBytes: 4096,
);

/// Fichier 17 : hello, thanks, alias de hello, hunter (brouillon existant).
StringTableFile smallFile() => StringTableFile(
  unknownHeader: 0,
  tables: [
    StringTable(
      originalOffsets: const [],
      slots: [
        StringSlot(index: 0, raw: b(hello)),
        StringSlot(index: 1, raw: b(thanks)),
        StringSlot(index: 2, raw: b(hello), aliasOf: 0),
        StringSlot(index: 3, raw: b(hunter)),
      ],
    ),
  ],
  endData: Uint8List(0),
);

/// Grand fichier : [n] chaînes japonaises distinctes (plusieurs lots).
StringTableFile bigFile(int n) => StringTableFile(
  unknownHeader: 0,
  tables: [
    StringTable(
      originalOffsets: const [],
      slots: [
        for (var i = 0; i < n; i++) StringSlot(index: i, raw: b('テ' * (i + 1))),
      ],
    ),
  ],
  endData: Uint8List(0),
);

class FakeSettings implements AiSettingsStore {
  FakeSettings(this.current);

  AiSettings current;
  var saves = 0;

  @override
  AiSettings load() => current;

  @override
  void save(AiSettings settings) {
    current = settings;
    saves++;
  }
}

/// Client factice : traduit d'après [dict] (ou `T<id>` pour tout), avec
/// barrière, erreur et liste de modèles configurables.
class FakeClient implements ChatClient {
  FakeClient({this.answerAll = false});

  final bool answerAll;
  Completer<void>? gate;
  TranslateError? failure;
  TranslateError? modelsFailure;
  final calls = <List<int>>[];
  final endpoints = <Uri>[];

  @override
  Future<ChatResult> chat({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    JsonSchemaFormat? jsonSchema,
  }) async {
    final req = (jsonDecode(messages[1].content) as Map)
        .cast<String, Object?>();
    final items = (req['items']! as List).cast<Map<String, Object?>>();
    calls.add([for (final i in items) i['id']! as int]);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    return ChatResult(
      content: jsonEncode({
        'items': [
          for (final i in items)
            if (answerAll)
              {'id': i['id'], 'text': 'T${i['id']}'}
            else if (dict.containsKey(i['text']))
              {'id': i['id'], 'text': dict[i['text']]},
        ],
      }),
      finishReason: 'stop',
      promptTokens: 10,
      completionTokens: 5,
    );
  }

  @override
  Future<List<String>> listModels() async {
    if (modelsFailure != null) throw modelsFailure!;
    return ['model-a', 'model-b'];
  }
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;
  late FakeClient client;
  late FakeSettings settings;

  Future<void> setUpDb(StringTableFile file) async {
    db = TdbDatabase.openInMemory();
    repo = TranslationRepository(db, locale: 'fr');
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'T',
      lba: 1,
      slotBytes: 4096,
      origBytes: 4096,
      file: file,
    );
  }

  setUp(() {
    client = FakeClient();
    settings = FakeSettings(
      const AiSettings(endpoint: 'http://127.0.0.1:1235/v1', model: 'model-a'),
    );
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    currentProjectProvider.overrideWithValue(project),
    translationRepositoryProvider.overrideWithValue(repo),
    glossaryRepositoryProvider.overrideWithValue(
      GlossaryRepository(db, locale: 'fr'),
    ),
    glossaryListProvider.overrideWith((ref) async => const <GlossaryTermRow>[]),
    translationMemoryProvider.overrideWith(
      (ref) async => TranslationMemory.fromPairs(const []),
    ),
    fileBudgetsProvider.overrideWith((ref) async => {17: baseBudget}),
    chatClientFactoryProvider.overrideWithValue((endpoint, key) {
      client.endpoints.add(endpoint);
      return client;
    }),
    aiSettingsStoreProvider.overrideWithValue(settings),
    aiApiKeyProvider.overrideWithValue(null),
  ];

  Future<void> openPage(WidgetTester t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(home: FileEditorPage(fileId: 17)),
      ),
    );
    await settle(t);
  }

  Future<void> openDialog(WidgetTester t) async {
    await t.tap(find.byKey(const Key('pretranslate')));
    await t.pumpAndSettle();
  }

  Future<List<SlotView>> slots(WidgetTester t) async =>
      (await t.runAsync(() => repo.slots(17)))!;

  Future<void> prepareSmall() async {
    await setUpDb(smallFile());
    final s = await repo.slots(17);
    await repo.saveTranslation(
      sourceId: s[3].sourceId,
      text: 'Brouillon existant',
      status: 'draft',
    );
  }

  testWidgets('the dialog starts from the saved settings', (t) async {
    await prepareSmall();
    await openPage(t);
    await openDialog(t);
    expect(find.text('Pré-traduire avec un modèle de langage'), findsOneWidget);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('ai-endpoint')))
          .controller!
          .text,
      'http://127.0.0.1:1235/v1',
    );
    expect(
      t.widget<TextField>(find.byKey(const Key('ai-model'))).controller!.text,
      'model-a',
    );
    // Aucune chaîne sélectionnée : la portée « sélection » est désactivée.
    expect(
      t
          .widget<RadioListTile<AiScope>>(
            find.byKey(const Key('ai-scope-selection')),
          )
          .enabled,
      isFalse,
    );
    expect(find.byKey(const Key('ai-remote-warning')), findsNothing);
  });

  testWidgets('estimate shows the plan without sending anything', (t) async {
    await prepareSmall();
    await openPage(t);
    await openDialog(t);
    await t.tap(find.byKey(const Key('ai-estimate')));
    await settle(t);
    // hello, thanks : sans traduction (hunter a un brouillon, alias ignoré).
    expect(find.textContaining('2 chaîne(s) en 1 lot(s)'), findsOneWidget);
    expect(client.calls, isEmpty);

    await t.tap(find.byKey(const Key('ai-scope-drafts')));
    await t.pump();
    await t.tap(find.byKey(const Key('ai-estimate')));
    await settle(t);
    expect(find.textContaining('3 chaîne(s) en 1 lot(s)'), findsOneWidget);
  });

  testWidgets('running saves drafts, shows the summary, badges and settings', (
    t,
  ) async {
    await prepareSmall();
    await openPage(t);
    await openDialog(t);
    await t.tap(find.byKey(const Key('ai-run')));
    await settle(t);
    expect(find.byKey(const Key('ai-summary')), findsOneWidget);
    expect(
      find.textContaining('2 brouillon(s) enregistré(s), 0 refusé(s)'),
      findsOneWidget,
    );
    expect(client.calls, hasLength(1));
    final stored = await slots(t);
    expect(stored[0].translation!.text, 'Bonjour.');
    expect(stored[0].translation!.status, 'draft');
    expect(stored[0].translation!.authorId, 'ai:model-a');
    expect(stored[3].translation!.text, 'Brouillon existant'); // intact
    expect(settings.saves, 1);

    await t.tap(find.byKey(const Key('ai-close')));
    await settle(t);
    expect(find.textContaining('· draft · IA'), findsNWidgets(2));
  });

  testWidgets('a model is required before running', (t) async {
    await prepareSmall();
    settings.current = const AiSettings(endpoint: 'http://127.0.0.1:1235/v1');
    await openPage(t);
    await openDialog(t);
    FilledButton run() =>
        t.widget<FilledButton>(find.byKey(const Key('ai-run')));
    expect(run().onPressed, isNull);
    await t.enterText(find.byKey(const Key('ai-model')), 'model-a');
    await t.pump();
    expect(run().onPressed, isNotNull);
  });

  testWidgets('a remote endpoint needs an explicit confirmation', (t) async {
    await prepareSmall();
    settings.current = const AiSettings(
      endpoint: 'https://api.example.com/v1',
      model: 'm',
    );
    await openPage(t);
    await openDialog(t);
    expect(find.byKey(const Key('ai-remote-warning')), findsOneWidget);
    expect(find.textContaining('api.example.com'), findsWidgets);
    FilledButton run() =>
        t.widget<FilledButton>(find.byKey(const Key('ai-run')));
    expect(run().onPressed, isNull);
    await t.tap(find.byKey(const Key('ai-confirm-remote')));
    await t.pump();
    expect(run().onPressed, isNotNull);
    // Changer l'adresse retire la confirmation.
    await t.enterText(
      find.byKey(const Key('ai-endpoint')),
      'https://autre.example.org/v1',
    );
    await t.pump();
    expect(run().onPressed, isNull);
  });

  testWidgets('models can be listed and errors are shown', (t) async {
    await prepareSmall();
    await openPage(t);
    await openDialog(t);
    await t.tap(find.byKey(const Key('ai-load-models')));
    await settle(t);
    expect(find.byKey(const Key('ai-model-menu')), findsOneWidget);

    client.modelsFailure = const TranslateError(
      TranslateErrorKind.unreachable,
      'cannot reach the server',
    );
    await t.enterText(
      find.byKey(const Key('ai-endpoint')),
      'http://127.0.0.1:9/v1',
    );
    await t.pump();
    await t.tap(find.byKey(const Key('ai-load-models')));
    await settle(t);
    expect(find.byKey(const Key('ai-error')), findsOneWidget);
    expect(find.textContaining('cannot reach the server'), findsOneWidget);
  });

  testWidgets('unsaved edits block the run', (t) async {
    await prepareSmall();
    await openPage(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[0].sourceId}')));
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'brouillon local');
    await settle(t);
    await openDialog(t);
    expect(find.byKey(const Key('ai-unsaved')), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('ai-run'))).onPressed,
      isNull,
    );
  });

  testWidgets('the selected string is retranslated, even a draft', (t) async {
    await prepareSmall();
    await openPage(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[3].sourceId}'))); // hunter (brouillon)
    await t.pump();
    await openDialog(t);
    expect(
      t
          .widget<RadioGroup<AiScope>>(find.byType(RadioGroup<AiScope>))
          .groupValue,
      AiScope.selection,
    );
    await t.tap(find.byKey(const Key('ai-run')));
    await settle(t);
    expect(client.calls.single, [s[3].sourceId]);
    final after = await slots(t);
    expect(after[3].translation!.text, 'Le Chasseur va en forêt.');
    expect(after[0].translation, isNull); // le reste du fichier est intact
  });

  testWidgets('a provider failure is reported and keeps the progress', (
    t,
  ) async {
    await prepareSmall();
    client.failure = const TranslateError(
      TranslateErrorKind.unreachable,
      'cannot reach the server',
    );
    await openPage(t);
    await openDialog(t);
    await t.tap(find.byKey(const Key('ai-run')));
    await settle(t);
    expect(find.byKey(const Key('ai-stopped')), findsOneWidget);
    expect(find.textContaining('0 brouillon(s) enregistré(s)'), findsOneWidget);
  });

  testWidgets('cancelling stops between batches and keeps what was saved', (
    t,
  ) async {
    await setUpDb(bigFile(45)); // 2 lots de 40 et 5
    client = FakeClient(answerAll: true)..gate = Completer<void>();
    await openPage(t);
    await openDialog(t);
    await t.tap(find.byKey(const Key('ai-scope-file')));
    await t.pump();
    await t.tap(find.byKey(const Key('ai-run')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('ai-progress')), findsOneWidget);
    expect(find.byKey(const Key('ai-cancel')), findsOneWidget);

    await t.tap(find.byKey(const Key('ai-cancel')));
    await t.pump();
    client.gate!.complete();
    await settle(t);
    expect(
      find.textContaining('Annulé : 5 chaîne(s) non traitée(s)'),
      findsOneWidget,
    );
    expect(client.calls, hasLength(1)); // le second lot n'est pas parti
    final saved = (await slots(t)).where((s) => s.translation != null).length;
    expect(saved, 40);
  });
}
