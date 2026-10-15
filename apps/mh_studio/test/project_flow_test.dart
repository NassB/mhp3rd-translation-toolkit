import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_studio/app/app.dart';
import 'package:mh_tdb/mh_tdb.dart';

Widget app() => const ProviderScope(child: StudioApp());

/// Projet minimal : project.json + base SQLite vide (schéma créé).
Future<String> makeProject(Directory tmp) async {
  final dir = '${tmp.path}/fr';
  Directory(dir).createSync();
  Project(
    dir: dir,
    isoPath: '${tmp.path}/game.iso',
    versionId: 'TEST',
    locale: 'fr',
  ).save();
  final db = TdbDatabase.openFile('$dir/$projectDbName');
  await db.customSelect('SELECT 1').get();
  await db.close();
  return dir;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('mh_studio_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('home asks for a project folder', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Ouvrir un projet'), findsOneWidget);
    expect(find.byKey(const Key('project-path')), findsOneWidget);
    expect(find.text('Projet'), findsNothing);
  });

  testWidgets('an invalid folder shows an error and stays home', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.enterText(
      find.byKey(const Key('project-path')),
      '${tmp.path}/absent',
    );
    await tester.tap(find.byKey(const Key('open-project')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a project'), findsOneWidget);
    expect(find.text('Ouvrir un projet'), findsOneWidget);
  });

  testWidgets('a folder without database is refused', (tester) async {
    final dir = '${tmp.path}/nodb';
    Directory(dir).createSync();
    Project(dir: dir, isoPath: 'x.iso', versionId: 'TEST', locale: 'fr').save();
    await tester.pumpWidget(app());
    await tester.enterText(find.byKey(const Key('project-path')), dir);
    await tester.tap(find.byKey(const Key('open-project')));
    await tester.pumpAndSettle();
    expect(find.textContaining('missing tdb.sqlite'), findsOneWidget);
  });

  testWidgets('opening a project shows its content, closing returns home', (
    tester,
  ) async {
    final dir = (await tester.runAsync(() => makeProject(tmp)))!;
    await tester.pumpWidget(app());
    await tester.enterText(find.byKey(const Key('project-path')), dir);
    await tester.tap(find.byKey(const Key('open-project')));
    await tester.pump();
    // La requête SQLite s'exécute hors de l'horloge simulée.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version : TEST'), findsOneWidget);
    expect(find.text('Locale : fr'), findsOneWidget);
    expect(find.text('Fichiers : 0'), findsOneWidget);
    expect(find.textContaining('untranslated'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-project')));
    await tester.pumpAndSettle();
    expect(find.text('Ouvrir un projet'), findsOneWidget);
  });
}
