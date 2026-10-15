import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_studio/features/ai/application/ai_providers.dart';
import 'package:mh_studio/features/glossary/application/glossary_providers.dart';
import 'package:mh_studio/features/glossary/application/term_suggestions.dart';
import 'package:mh_studio/features/glossary/presentation/glossary_page.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:mh_translate/mh_translate.dart';

const _rathalos = TermCandidate(term: 'リオレウス', count: 5, example: 'x');
const _wyvern = TermCandidate(term: '火竜', count: 3, example: 'y');

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
  late List<String> proposedEndpoints;

  setUp(() {
    db = TdbDatabase.openInMemory();
    repo = GlossaryRepository(db, locale: 'fr');
    proposedEndpoints = [];
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    glossaryRepositoryProvider.overrideWithValue(repo),
    aiSettingsStoreProvider.overrideWithValue(null),
    termScannerProvider.overrideWithValue(
      ({int minCount = 3}) async => const [_rathalos, _wyvern],
    ),
    termProposerProvider.overrideWithValue(({
      required endpoint,
      required model,
      required candidates,
      isCancelled,
    }) async {
      proposedEndpoints.add(endpoint);
      return {'リオレウス': 'Rathalos'};
    }),
  ];

  Future<void> openDialog(WidgetTester t) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const MaterialApp(home: GlossaryPage()),
      ),
    );
    await settle(t);
    await t.tap(find.byKey(const Key('suggest-terms')));
    await settle(t);
  }

  Future<void> scan(WidgetTester t) async {
    await t.tap(find.byKey(const Key('suggest-scan')));
    await settle(t);
  }

  testWidgets('scan lists candidates, nothing is added by itself', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await openDialog(t);
    expect(find.byKey(const Key('cand-0')), findsNothing);
    await scan(t);
    expect(find.textContaining('リオレウス'), findsOneWidget);
    expect(find.textContaining('×5'), findsOneWidget);
    expect(await repo.all(), isEmpty);
    // Bouton d'ajout inactif tant que rien n'est coché et traduit.
    final add = t.widget<FilledButton>(find.byKey(const Key('suggest-add')));
    expect(add.onPressed, isNull);
  });

  testWidgets('propose fills the field, only checked terms are added', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await openDialog(t);
    await scan(t);
    await t.enterText(
      find.byKey(const Key('suggest-endpoint')),
      'http://127.0.0.1:1235/v1',
    );
    await t.enterText(find.byKey(const Key('suggest-model')), 'm');
    await t.tap(find.byKey(const Key('suggest-propose')));
    await settle(t);
    expect(proposedEndpoints, ['http://127.0.0.1:1235/v1']);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('cand-text-0')))
          .controller!
          .text,
      'Rathalos',
    );
    // Non coché : toujours rien d'ajouté.
    expect(await repo.all(), isEmpty);
    await t.tap(find.byKey(const Key('cand-check-0')));
    await t.pump();
    await t.tap(find.byKey(const Key('suggest-add')));
    await settle(t);
    final terms = await t.runAsync(repo.all);
    expect(
      [for (final x in terms!) '${x.sourceTerm}=${x.targetTerm}'],
      ['リオレウス=Rathalos'],
    );
    expect(find.byKey(const Key('cand-1')), findsNothing); // l'ajouté a disparu
    expect(find.text('火竜', findRichText: true), findsNothing);
  });

  testWidgets('a manual translation can be added without the model', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await openDialog(t);
    await scan(t);
    await t.enterText(find.byKey(const Key('cand-text-1')), 'Wyvern de feu');
    await t.tap(find.byKey(const Key('cand-check-1')));
    await t.pump();
    await t.tap(find.byKey(const Key('suggest-add')));
    await settle(t);
    final terms = await t.runAsync(repo.all);
    expect(terms!.single.targetTerm, 'Wyvern de feu');
  });

  testWidgets('a remote server is refused before any request', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await openDialog(t);
    await scan(t);
    await t.enterText(
      find.byKey(const Key('suggest-endpoint')),
      'https://api.example.com/v1',
    );
    await t.enterText(find.byKey(const Key('suggest-model')), 'm');
    await t.tap(find.byKey(const Key('suggest-propose')));
    await settle(t);
    expect(proposedEndpoints, isEmpty);
    expect(find.textContaining('serveur local'), findsOneWidget);
  });
}
