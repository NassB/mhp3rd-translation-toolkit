import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_studio/features/dump/application/dump_actions.dart';
import 'package:mh_studio/features/dump/presentation/dump_dialog.dart';

class FakeDumpActions extends DumpActions {
  final calls = <String>[];
  Object? error;
  int imported = 3;
  int tables = 2;

  @override
  Future<int> importFolder({
    required int fileId,
    required String folder,
    required String status,
  }) async {
    calls.add('import $fileId $folder $status');
    if (error != null) throw error!;
    return imported;
  }

  @override
  Future<int> exportFolder({
    required int fileId,
    required String folder,
  }) async {
    calls.add('export $fileId $folder');
    if (error != null) throw error!;
    return tables;
  }
}

Widget host(FakeDumpActions fake, DumpMode mode) => ProviderScope(
  overrides: [dumpActionsProvider.overrideWith(() => fake)],
  child: MaterialApp(
    home: Scaffold(body: DumpDialog(mode: mode, fileId: 17)),
  ),
);

void main() {
  testWidgets('import sends the folder and the chosen status', (t) async {
    final fake = FakeDumpActions();
    await t.pumpWidget(host(fake, DumpMode.import));
    await t.enterText(find.byKey(const Key('dump-path')), ' /tmp/dump ');
    await t.tap(find.byKey(const Key('dump-status')));
    await t.pumpAndSettle();
    await t.tap(find.text('translated').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(fake.calls, ['import 17 /tmp/dump translated']);
    expect(
      find.text('3 traduction(s) créée(s) ou modifiée(s).'),
      findsOneWidget,
    );
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('an import with no change says so', (t) async {
    final fake = FakeDumpActions()..imported = 0;
    await t.pumpWidget(host(fake, DumpMode.import));
    await t.enterText(find.byKey(const Key('dump-path')), 'd');
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(
      find.text('Aucune traduction nouvelle ou modifiée.'),
      findsOneWidget,
    );
  });

  testWidgets('export sends the destination and shows the table count', (
    t,
  ) async {
    final fake = FakeDumpActions();
    await t.pumpWidget(host(fake, DumpMode.export));
    expect(find.byKey(const Key('dump-status')), findsNothing);
    await t.enterText(find.byKey(const Key('dump-path')), 'out/dump17');
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(fake.calls, ['export 17 out/dump17']);
    expect(find.text('Dump écrit (2 table(s)).'), findsOneWidget);
  });

  testWidgets('an empty path is refused without calling the action', (t) async {
    final fake = FakeDumpActions();
    await t.pumpWidget(host(fake, DumpMode.import));
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(find.text('Indiquez un dossier.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('domain, file and format errors are shown', (t) async {
    final fake = FakeDumpActions();
    await t.pumpWidget(host(fake, DumpMode.import));
    await t.enterText(find.byKey(const Key('dump-path')), 'd');

    fake.error = const TdbError('file not imported');
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(find.text('file not imported'), findsOneWidget);

    fake.error = const FileSystemException('dump folder not found', 'd');
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(find.textContaining('dump folder not found: d'), findsOneWidget);

    fake.error = const FormatException('bad utf8');
    await t.tap(find.byKey(const Key('dump-run')));
    await t.pumpAndSettle();
    expect(find.textContaining('Texte invalide'), findsOneWidget);
    expect(find.byKey(const Key('dump-result')), findsNothing);
  });
}
