import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_studio/features/status/presentation/bulk_status_dialog.dart';
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

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;

  setUp(() async {
    db = TdbDatabase.openInMemory();
    repo = TranslationRepository(db, locale: 'fr');
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
              StringSlot(index: 0, raw: b('a')),
              StringSlot(index: 1, raw: b('b')),
            ],
          ),
          StringTable(
            originalOffsets: const [],
            slots: [StringSlot(index: 0, raw: b('c'))],
          ),
        ],
        endData: Uint8List(0),
      ),
    );
    for (final s in await repo.slots(17)) {
      await repo.saveTranslation(
        sourceId: s.sourceId,
        text: 'T${s.tableIdx}${s.slotIdx}',
        status: 'draft',
      );
    }
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    translationRepositoryProvider.overrideWithValue(repo),
  ];

  Future<void> open(WidgetTester t, {int unsaved = 0}) async {
    await t.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          home: Scaffold(
            body: BulkStatusDialog(
              fileId: 17,
              tables: const [0, 1],
              unsavedCount: unsaved,
            ),
          ),
        ),
      ),
    );
    await settle(t);
  }

  Future<Map<String, String>> statuses() async => {
    for (final s in await repo.slots(17))
      '${s.tableIdx}.${s.slotIdx}': s.translation!.status,
  };

  testWidgets('previews the whole file, then applies it', (t) async {
    await open(t);
    expect(find.text('3 traduction(s) concernée(s).'), findsOneWidget);
    await t.tap(find.byKey(const Key('bulk-apply')));
    await settle(t);
    expect(find.textContaining('3 traduction(s) passée(s)'), findsOneWidget);
    final s = await t.runAsync(statuses);
    expect(s!.values.toSet(), {'translated'});
  });

  testWidgets('a table scope changes only that table', (t) async {
    await open(t);
    await t.tap(find.byKey(const Key('bulk-scope')));
    await settle(t);
    await t.tap(find.text('Table 1').last);
    await settle(t);
    expect(find.text('1 traduction(s) concernée(s).'), findsOneWidget);
    await t.tap(find.byKey(const Key('bulk-apply')));
    await settle(t);
    final s = await t.runAsync(statuses);
    expect(s, {'0.0': 'draft', '0.1': 'draft', '1.0': 'translated'});
  });

  testWidgets('no source status: nothing can be applied', (t) async {
    await open(t);
    await t.tap(find.byKey(const Key('bulk-from-draft')));
    await settle(t);
    expect(find.text('Choisis au moins un statut de départ.'), findsOneWidget);
    final apply = t.widget<FilledButton>(find.byKey(const Key('bulk-apply')));
    expect(apply.onPressed, isNull);
  });

  testWidgets('locked source shows a warning', (t) async {
    await open(t);
    await t.tap(find.byKey(const Key('bulk-from-locked')));
    await settle(t);
    expect(find.byKey(const Key('bulk-locked-warning')), findsOneWidget);
  });

  testWidgets('unsaved editor changes block the application', (t) async {
    await open(t, unsaved: 2);
    expect(find.byKey(const Key('bulk-unsaved')), findsOneWidget);
    final apply = t.widget<FilledButton>(find.byKey(const Key('bulk-apply')));
    expect(apply.onPressed, isNull);
    final s = await t.runAsync(statuses);
    expect(s!.values.toSet(), {'draft'});
  });
}
