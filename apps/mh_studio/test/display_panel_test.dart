import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_studio/features/display/application/display_providers.dart';
import 'package:mh_studio/features/display/presentation/display_panel.dart';
import 'package:mh_studio/features/display/presentation/display_preview.dart';
import 'package:mh_tdb/mh_tdb.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 60));
  }
}

final metrics = GlyphMetrics(
  contexts: const [FontContext(id: 'px7', advancePx: 7)],
);
final profiles = LengthProfiles(const [
  LengthProfile(
    id: 'tight',
    description: 'très étroit',
    fontContext: 'px7',
    maxPx: 28,
    maxLines: 1,
  ),
  LengthProfile(id: 'nofont', maxLines: 2),
  LengthProfile(
    id: 'dialogue',
    fontContext: 'px7',
    maxPx: 70,
    maxLines: 1,
    paginated: true,
  ),
]);
final check = DisplayCheck(profiles: profiles, metrics: metrics);

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;
  late ProfileRepository profileRepo;

  setUp(() async {
    db = TdbDatabase.openInMemory();
    repo = TranslationRepository(db, locale: 'fr');
    profileRepo = ProfileRepository(db);
    await importSourceFile(
      db,
      fileId: 17,
      versionId: 'T',
      lba: 1,
      slotBytes: 4096,
      origBytes: 4096,
      file: StringTableFile(
        unknownHeader: 0,
        tables: [
          StringTable(
            originalOffsets: const [],
            slots: [
              StringSlot(index: 0, raw: b('あいう')),
              StringSlot(index: 1, raw: b('えおか')),
            ],
          ),
          StringTable(
            originalOffsets: const [],
            slots: [StringSlot(index: 0, raw: b('きくけ'))],
          ),
        ],
        endData: Uint8List(0),
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester t, {
    required String text,
    DisplayConfig? config,
    int slotIdx = 0,
  }) async {
    await t.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final slot = (await t.runAsync(() => repo.slots(17)))!
        .firstWhere((s) => s.tableIdx == 0 && s.slotIdx == slotIdx);
    final List<Override> overrides = [
      displayConfigProvider.overrideWithValue(
        config ?? DisplayConfig.loaded(check),
      ),
      profileRepositoryProvider.overrideWithValue(profileRepo),
    ];
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisplayPanel(fileId: 17, slot: slot, text: text),
            ),
          ),
        ),
      ),
    );
    await settle(t);
  }

  Future<int> sourceId(int table, int slot) async =>
      (await repo.slots(17))
          .firstWhere((s) => s.tableIdx == table && s.slotIdx == slot)
          .sourceId;

  testWidgets('unavailable or invalid configuration is explained', (t) async {
    await open(t, text: 'abc', config: const DisplayConfig.missing());
    expect(find.textContaining('indisponibles'), findsOneWidget);
    await open(t, text: 'abc', config: const DisplayConfig.invalid('boom'));
    expect(find.textContaining('invalides : boom'), findsOneWidget);
  });

  testWidgets('no profile: only the menu, no warnings, no preview', (t) async {
    await open(t, text: 'abcdefgh');
    expect(find.byKey(const Key('profile-menu')), findsOneWidget);
    expect(find.text('Aucun profil'), findsOneWidget);
    expect(find.byKey(const Key('display-summary')), findsNothing);
    expect(find.byKey(const Key('display-preview')), findsNothing);
  });

  testWidgets('the file profile gives warnings in French and a preview', (
    t,
  ) async {
    await profileRepo.setFileProfile(17, 'tight');
    await open(t, text: 'abcdef\nsecond');
    expect(
      find.textContaining('Limites : 28 px (px7) ; 1 ligne(s).'),
      findsOne,
    );
    expect(find.text('2 ligne(s), largeur 42 px'), findsOneWidget);
    expect(find.text('Ligne 1 : 42 px pour 28 px autorisés.'), findsOneWidget);
    expect(find.text('Ligne 2 : 42 px pour 28 px autorisés.'), findsOneWidget);
    expect(find.text('2 lignes pour 1 autorisées.'), findsOneWidget);
    expect(find.byKey(const Key('display-preview')), findsOneWidget);
    expect(find.byKey(const Key('display-limit')), findsOneWidget);
    expect(find.byKey(const Key('display-inexact')), findsNothing);
  });

  testWidgets('a text within the limits has no issue', (t) async {
    await profileRepo.setFileProfile(17, 'tight');
    await open(t, text: 'abcd');
    expect(find.text('1 ligne(s), largeur 28 px'), findsOneWidget);
    expect(find.byKey(const Key('display-issue-0')), findsNothing);
  });

  testWidgets('codes and unmeasured glyphs: minimum width and a warning', (
    t,
  ) async {
    await profileRepo.setFileProfile(17, 'tight');
    await open(t, text: '~C02a…');
    expect(find.text('1 ligne(s), largeur ≥ 7 px'), findsOneWidget);
    expect(
      find.textContaining('Caractère « … » (U+2026) : largeur non mesurée'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('display-inexact')), findsOneWidget);
  });

  testWidgets('a profile without font has no preview', (t) async {
    await profileRepo.setFileProfile(17, 'nofont');
    await open(t, text: 'a\nb\nc');
    expect(
      find.byKey(const Key('display-preview-unavailable')),
      findsOneWidget,
    );
    expect(find.text('3 lignes pour 2 autorisées.'), findsOneWidget);
  });

  testWidgets('a paginated profile does not check the line count', (t) async {
    await profileRepo.setFileProfile(17, 'dialogue');
    await open(t, text: 'a\nb\nc');
    expect(find.textContaining('lignes pour'), findsNothing);
    expect(find.textContaining('paginé (lignes non contrôlées)'), findsOne);
  });

  testWidgets('picking a profile previews it before it is assigned', (t) async {
    await open(t, text: 'abcdefgh');
    await t.tap(find.byKey(const Key('profile-menu')));
    await settle(t);
    await t.tap(find.text('tight').last);
    await settle(t);
    expect(find.text('Ligne 1 : 56 px pour 28 px autorisés.'), findsOneWidget);
    expect(await profileRepo.fileProfile(17), isNull); // rien d'enregistré
  });

  testWidgets('the three scopes assign the picked profile', (t) async {
    await open(t, text: 'abc', slotIdx: 1);
    await t.tap(find.byKey(const Key('profile-menu')));
    await settle(t);
    await t.tap(find.text('nofont').last);
    await settle(t);

    await t.tap(find.byKey(const Key('profile-apply-string')));
    await settle(t);
    final one = await t.runAsync(() async => sourceId(0, 1));
    var m = (await t.runAsync(() => profileRepo.effectiveProfiles(17)))!;
    expect(m[one], 'nofont');
    expect(m[await t.runAsync(() async => sourceId(0, 0))], isNull);

    await t.tap(find.byKey(const Key('profile-apply-table')));
    await settle(t);
    m = (await t.runAsync(() => profileRepo.effectiveProfiles(17)))!;
    expect(m[await t.runAsync(() async => sourceId(0, 0))], 'nofont');
    expect(m[await t.runAsync(() async => sourceId(1, 0))], isNull);

    await t.tap(find.byKey(const Key('profile-apply-file')));
    await settle(t);
    expect(await t.runAsync(() => profileRepo.fileProfile(17)), 'nofont');
    m = (await t.runAsync(() => profileRepo.effectiveProfiles(17)))!;
    expect(m.values.toSet(), {'nofont'});
  });

  testWidgets('choosing no profile clears the assignment', (t) async {
    await profileRepo.setFileProfile(17, 'tight');
    await open(t, text: 'abc');
    await t.tap(find.byKey(const Key('profile-menu')));
    await settle(t);
    await t.tap(find.text('Aucun profil').last);
    await settle(t);
    await t.tap(find.byKey(const Key('profile-apply-file')));
    await settle(t);
    expect(await t.runAsync(() => profileRepo.fileProfile(17)), isNull);
  });

  testWidgets('preview: characters beyond the limit are drawn in red', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final profile = profiles['tight']!; // 28 px = 4 caractères
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DisplayPreview(
            text: 'abcdefg',
            profile: profile,
            metrics: metrics,
          ),
        ),
      ),
    );
    final texts = t.widgetList<Text>(find.byType(Text)).toList();
    final colors = {for (final x in texts) x.data!: x.style?.color};
    for (final c in ['a', 'b', 'c', 'd']) {
      expect(colors[c], isNull, reason: c);
    }
    for (final c in ['e', 'f', 'g']) {
      expect(colors[c], isNotNull, reason: c);
    }
    // Une cellule = le pas du contexte, à l'échelle.
    final size = t.getSize(
      find.ancestor(of: find.text('a'), matching: find.byType(Container)).first,
    );
    expect(size.width, 7 * previewScale);
  });
}
