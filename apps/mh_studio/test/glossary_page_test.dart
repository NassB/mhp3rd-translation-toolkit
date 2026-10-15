import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_studio/app/router.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_studio/features/glossary/application/glossary_providers.dart';
import 'package:mh_studio/features/glossary/presentation/glossary_page.dart';
import 'package:mh_studio/features/project/application/project_providers.dart';
import 'package:mh_tdb/mh_tdb.dart';

const project = Project(
  dir: 'p',
  isoPath: 'x.iso',
  versionId: 'TEST',
  locale: 'fr',
);

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
  late GlossaryRepository repo;

  setUp(() {
    db = TdbDatabase.openInMemory();
    repo = GlossaryRepository(db, locale: 'fr');
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    glossaryRepositoryProvider.overrideWithValue(repo),
  ];

  Future<void> openPage(WidgetTester t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(home: GlossaryPage()),
      ),
    );
    await settle(t);
  }

  Future<void> fillAndSave(
    WidgetTester t, {
    String? source,
    required String target,
    bool mandatory = false,
  }) async {
    if (source != null) {
      await t.enterText(find.byKey(const Key('term-source')), source);
    }
    await t.enterText(find.byKey(const Key('term-target')), target);
    if (mandatory) await t.tap(find.byKey(const Key('term-mandatory')));
    await t.tap(find.byKey(const Key('term-save')));
    await settle(t);
  }

  testWidgets('an empty glossary says so', (t) async {
    await openPage(t);
    expect(find.text('Aucun terme dans le glossaire.'), findsOneWidget);
  });

  testWidgets('adds a mandatory term and lists it', (t) async {
    await openPage(t);
    await t.tap(find.byKey(const Key('add-term')));
    await t.pumpAndSettle();
    await fillAndSave(t, source: 'リオレウス', target: 'Rathalos', mandatory: true);
    expect(find.text('リオレウス → Rathalos'), findsOneWidget);
    expect(find.byKey(const Key('mandatory-icon')), findsOneWidget);
    final stored = (await t.runAsync(() => repo.all()))!;
    expect(stored.single.mandatory, isTrue);
  });

  testWidgets('a duplicate source term shows the error and keeps the dialog', (
    t,
  ) async {
    await t.runAsync(() => repo.add(sourceTerm: 'a', targetTerm: 'A'));
    await openPage(t);
    await t.tap(find.byKey(const Key('add-term')));
    await t.pumpAndSettle();
    await fillAndSave(t, source: 'a', target: 'B');
    expect(find.byKey(const Key('term-error')), findsOneWidget);
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.text('Nouveau terme'), findsOneWidget);
  });

  testWidgets('an empty target is refused', (t) async {
    await openPage(t);
    await t.tap(find.byKey(const Key('add-term')));
    await t.pumpAndSettle();
    await fillAndSave(t, source: 'a', target: '  ');
    expect(find.textContaining('empty glossary term'), findsOneWidget);
    expect((await t.runAsync(() => repo.all()))!, isEmpty);
  });

  testWidgets('edits a term; the source term is locked', (t) async {
    final id = (await t.runAsync(
      () => repo.add(sourceTerm: 'ハンター', targetTerm: 'Chasseur'),
    ))!;
    await openPage(t);
    await t.tap(find.byKey(Key('edit-$id')));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byKey(const Key('term-source'))).enabled,
      isFalse,
    );
    await fillAndSave(t, target: 'Chasseuse');
    expect(find.text('ハンター → Chasseuse'), findsOneWidget);
  });

  testWidgets('deletes a term', (t) async {
    final id = (await t.runAsync(
      () => repo.add(sourceTerm: 'a', targetTerm: 'A'),
    ))!;
    await openPage(t);
    await t.tap(find.byKey(Key('delete-$id')));
    await settle(t);
    expect(find.byKey(Key('term-$id')), findsNothing);
    expect(find.text('Aucun terme dans le glossaire.'), findsOneWidget);
  });

  testWidgets('the project page opens the glossary', (t) async {
    final router = buildRouter();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides(),
          currentProjectProvider.overrideWithValue(project),
          fileListProvider.overrideWith((ref) async => const <FileProgress>[]),
          fileBudgetsProvider.overrideWith(
            (ref) async => const <int, FileBudget>{},
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(Routes.project);
    await settle(t);
    await t.tap(find.byKey(const Key('open-glossary')));
    await settle(t);
    expect(find.text('Glossaire'), findsWidgets);
    expect(find.byKey(const Key('add-term')), findsOneWidget);
  });
}
