import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_studio/app/router.dart';
import 'package:mh_studio/features/editor/presentation/file_editor_page.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_studio/features/glossary/application/glossary_providers.dart';
import 'package:mh_studio/features/memory/application/memory_providers.dart';
import 'package:mh_studio/features/project/application/project_providers.dart';
import 'package:mh_tdb/mh_tdb.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

StringTableFile sample() => StringTableFile(
  unknownHeader: 0,
  tables: [
    StringTable(
      originalOffsets: const [],
      slots: [
        StringSlot(index: 0, raw: b('un\ndeux')),
        StringSlot(index: 1, raw: b('trois')),
        StringSlot(index: 2, raw: b('un\ndeux'), aliasOf: 0),
      ],
    ),
  ],
  endData: Uint8List(0),
);

const baseBudget = FileBudget(
  fileId: 17,
  origBytes: 2048,
  slotBytes: 2048,
  rebuiltBytes: 2040,
);

const project = Project(
  dir: 'p',
  isoPath: 'x.iso',
  versionId: 'TEST',
  locale: 'fr',
);

/// Laisse les futures réelles (SQLite en mémoire) puis les timers simulés
/// avancer.
Future<void> settle(WidgetTester t, {int ms = 250}) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(Duration(milliseconds: ms ~/ 4));
  }
}

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;

  setUp(() async {
    db = TdbDatabase.openInMemory();
    repo = TranslationRepository(db, locale: 'fr');
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'TEST',
      lba: 1,
      slotBytes: 2048,
      origBytes: 2048,
      file: sample(),
    );
  });
  tearDown(() => db.close());

  List<Override> overrides({
    List<GlossaryTermRow> glossary = const [],
    TranslationMemory? memory,
  }) => [
    glossaryListProvider.overrideWith((ref) async => glossary),
    translationMemoryProvider.overrideWith(
      (ref) async => memory ?? TranslationMemory.fromPairs(const []),
    ),
    translationRepositoryProvider.overrideWithValue(repo),
    fileBudgetsProvider.overrideWith((ref) async => {17: baseBudget}),
  ];

  Future<void> openEditor(
    WidgetTester t, {
    List<GlossaryTermRow> glossary = const [],
    TranslationMemory? memory,
  }) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides(glossary: glossary, memory: memory),
        child: const MaterialApp(home: FileEditorPage(fileId: 17)),
      ),
    );
    await settle(t);
  }

  Future<List<SlotView>> slots(WidgetTester t) async =>
      (await t.runAsync(() => repo.slots(17)))!;

  testWidgets('lists the strings and shows the file gauge', (t) async {
    await openEditor(t);
    final s = await slots(t);
    expect(find.byKey(Key('slot-${s[0].sourceId}')), findsOneWidget);
    expect(find.byKey(Key('slot-${s[2].sourceId}')), findsOneWidget);
    expect(find.textContaining('alias du slot 0'), findsOneWidget);
    expect(find.byKey(const Key('live-gauge')), findsOneWidget);
    expect(
      find.textContaining('2040 / 2048 o · marge 8 o · strict'),
      findsOneWidget,
    );
    expect(find.text('Choisissez une chaîne.'), findsOneWidget);
  });

  testWidgets('selecting a string shows its source with newline chips', (
    t,
  ) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[0].sourceId}')));
    await t.pump();
    expect(find.byKey(const Key('target-field')), findsOneWidget);
    expect(find.text('↵'), findsOneWidget); // le saut de ligne de la source
    expect(find.byKey(const Key('save-button')), findsOneWidget);
    final save = t.widget<FilledButton>(find.byKey(const Key('save-button')));
    expect(save.onPressed, isNull); // rien à enregistrer
  });

  testWidgets('typing marks the string dirty and drives the live gauge', (
    t,
  ) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}'))); // 'trois' (5 o)
    await t.pump();

    await t.enterText(find.byKey(const Key('target-field')), 'cinq !!'); // +2
    await settle(t);
    expect(find.byKey(const Key('dirty-dot')), findsOneWidget);
    expect(
      find.textContaining('2042 / 2048 o · marge 6 o · strict'),
      findsOneWidget,
    );

    await t.enterText(find.byKey(const Key('target-field')), 'x' * 20); // +15
    await settle(t);
    expect(
      find.textContaining('2055 / 2048 o · marge -7 o · dépassé'),
      findsOneWidget,
    );

    await t.tap(find.byKey(const Key('discard-button')));
    await settle(t);
    expect(find.byKey(const Key('dirty-dot')), findsNothing);
    expect(find.textContaining('2040 / 2048 o'), findsOneWidget);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('target-field')))
          .controller!
          .text,
      '',
    );
  });

  testWidgets('saving stores the translation and clears the dirty mark', (
    t,
  ) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'three');
    await settle(t);

    await t.tap(find.byKey(const Key('save-button')));
    await settle(t);
    expect(find.byKey(const Key('dirty-dot')), findsNothing);
    expect(find.textContaining('0.1 · draft'), findsOneWidget);
    final stored = await slots(t);
    expect(stored[1].translation!.text, 'three');
    expect(stored[1].translation!.status, 'draft');
    expect(find.textContaining('2040 / 2048 o'), findsOneWidget); // 5 -> 5 o
  });

  testWidgets('the status menu changes the draft status', (t) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'three');
    await settle(t);

    await t.tap(find.byKey(const Key('status-menu')));
    await t.pumpAndSettle();
    await t.tap(find.text('translated').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('save-button')));
    await settle(t);
    expect((await slots(t))[1].translation!.status, 'translated');
  });

  testWidgets('an alias is read-only', (t) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[2].sourceId}')));
    await t.pump();
    expect(find.byKey(const Key('alias-note')), findsOneWidget);
    expect(find.byKey(const Key('target-field')), findsNothing);
  });

  testWidgets('a conflict offers to reload or keep the draft', (t) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'MIEN');
    await settle(t);
    // Un autre traducteur enregistre avant nous.
    await t.runAsync(
      () => repo.saveTranslation(
        sourceId: s[1].sourceId,
        text: 'LEUR',
        status: 'translated',
      ),
    );

    await t.tap(find.byKey(const Key('save-button')));
    await settle(t);
    expect(find.byKey(const Key('conflict-banner')), findsOneWidget);
    expect(find.textContaining('révision 1'), findsOneWidget);

    await t.tap(find.byKey(const Key('conflict-reload')));
    await settle(t);
    expect(find.byKey(const Key('conflict-banner')), findsNothing);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('target-field')))
          .controller!
          .text,
      'LEUR',
    );
  });

  testWidgets('keeping the draft after a conflict allows the next save', (
    t,
  ) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'MIEN');
    await settle(t);
    await t.runAsync(
      () => repo.saveTranslation(
        sourceId: s[1].sourceId,
        text: 'LEUR',
        status: 'translated',
      ),
    );
    await t.tap(find.byKey(const Key('save-button')));
    await settle(t);
    await t.tap(find.byKey(const Key('conflict-keep')));
    await settle(t);
    await t.tap(find.byKey(const Key('save-button')));
    await settle(t);
    final stored = await slots(t);
    expect(stored[1].translation!.text, 'MIEN');
    expect(stored[1].translation!.revision, 2);
  });

  testWidgets('tapping a file in the list opens its editor', (t) async {
    final router = buildRouter();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides(),
          currentProjectProvider.overrideWithValue(project),
          fileListProvider.overrideWith(
            (ref) async => [
              FileProgress(
                id: 17,
                versionId: 'TEST',
                codec: 'string_table_a',
                lba: 1,
                slotBytes: 2048,
                origBytes: 2048,
                label: null,
                totalStrings: 2,
                byStatus: const {'untranslated': 2},
              ),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(Routes.project);
    await settle(t);
    await t.tap(find.byKey(const Key('file-17')));
    await settle(t);
    expect(find.text('Fichier #17'), findsOneWidget);
    expect(find.byKey(const Key('live-gauge')), findsOneWidget);
  });

  const three = GlossaryTermRow(
    id: 1,
    locale: 'fr',
    sourceTerm: 'trois',
    targetTerm: 'three',
    note: null,
    mandatory: true,
  );

  testWidgets('glossary terms found in the source can be inserted', (t) async {
    await openEditor(t, glossary: const [three]);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}'))); // 'trois'
    await t.pump();
    await settle(t); // le glossaire se charge à l'ouverture du panneau
    expect(find.byKey(const Key('glossary-trois')), findsOneWidget);

    await t.tap(find.byKey(const Key('glossary-trois')));
    await settle(t);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('target-field')))
          .controller!
          .text,
      'three',
    );
    expect(find.byKey(const Key('dirty-dot')), findsOneWidget);
    expect(find.byKey(const Key('lint-list')), findsNothing); // terme présent
  });

  testWidgets('a missing mandatory term is flagged', (t) async {
    await openEditor(t, glossary: const [three]);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'trois !');
    await settle(t);
    expect(find.byKey(const Key('lint-list')), findsOneWidget);
    expect(
      find.textContaining('Terme obligatoire absent : « three »'),
      findsOneWidget,
    );
  });

  testWidgets('a newline mismatch is flagged as an error', (t) async {
    await openEditor(t);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[0].sourceId}'))); // 'un\ndeux'
    await t.pump();
    await t.enterText(find.byKey(const Key('target-field')), 'one two');
    await settle(t);
    expect(
      find.textContaining('Nombre de sauts de ligne différent'),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const Key('target-field')), 'one\ntwo');
    await settle(t);
    expect(find.byKey(const Key('lint-list')), findsNothing);
  });

  testWidgets('an untouched string shows no lint', (t) async {
    await openEditor(t, glossary: const [three]);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    expect(find.byKey(const Key('lint-list')), findsNothing);
  });

  testWidgets('an exact memory match can be reused', (t) async {
    final memory = TranslationMemory.fromPairs([
      (id: 9001, source: 'trois', target: 'three (mémoire)'),
    ]);
    await openEditor(t, memory: memory);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}'))); // 'trois'
    await t.pump();
    await settle(t);
    expect(find.text('Mémoire de traduction'), findsOneWidget);
    expect(find.textContaining('100 % · exacte'), findsOneWidget);

    await t.tap(find.byKey(const Key('tm-use')));
    await settle(t);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('target-field')))
          .controller!
          .text,
      'three (mémoire)',
    );
    expect(find.byKey(const Key('dirty-dot')), findsOneWidget);
  });

  testWidgets('a fuzzy match shows its score and its source', (t) async {
    final memory = TranslationMemory.fromPairs([
      (id: 9001, source: 'trois!', target: 'three!'),
    ]);
    await openEditor(t, memory: memory);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}')));
    await t.pump();
    await settle(t);
    expect(find.textContaining('exacte'), findsNothing);
    expect(find.textContaining(' % · fichier 0'), findsOneWidget);
    expect(find.text('trois!'), findsOneWidget);
    expect(find.text('three!'), findsOneWidget);
  });

  testWidgets('no suggestion section without a match or on an alias', (
    t,
  ) async {
    final memory = TranslationMemory.fromPairs([
      (id: 9001, source: 'un\ndeux', target: 'one\ntwo'),
    ]);
    await openEditor(t, memory: memory);
    final s = await slots(t);
    await t.tap(find.byKey(Key('slot-${s[1].sourceId}'))); // 'trois' : rien
    await t.pump();
    await settle(t);
    expect(find.text('Mémoire de traduction'), findsNothing);

    await t.tap(find.byKey(Key('slot-${s[2].sourceId}'))); // alias
    await t.pump();
    await settle(t);
    expect(find.text('Mémoire de traduction'), findsNothing);
  });
}
