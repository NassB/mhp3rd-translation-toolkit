import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_studio/features/files/presentation/budget_gauge.dart';
import 'package:mh_studio/features/project/application/project_providers.dart';
import 'package:mh_studio/features/project/presentation/project_page.dart';
import 'package:mh_tdb/mh_tdb.dart';

const project = Project(
  dir: 'p',
  isoPath: 'x.iso',
  versionId: 'ULJM05800',
  locale: 'fr',
);

FileProgress file(int id, {String? label, int total = 10, int done = 0}) =>
    FileProgress(
      id: id,
      versionId: 'ULJM05800',
      codec: 'string_table_a',
      lba: 1,
      slotBytes: 4096,
      origBytes: 4096,
      label: label,
      totalStrings: total,
      byStatus: {'untranslated': total - done, 'translated': done},
    );

FileBudget budget(int id, int rebuilt) => FileBudget(
  fileId: id,
  origBytes: 4096,
  slotBytes: 4096,
  rebuiltBytes: rebuilt,
);

Widget app(List<Override> overrides) => ProviderScope(
  overrides: [currentProjectProvider.overrideWithValue(project), ...overrides],
  child: const MaterialApp(home: ProjectPage()),
);

void main() {
  testWidgets('lists files with progress and budget gauges', (tester) async {
    await tester.pumpWidget(
      app([
        fileListProvider.overrideWith(
          (ref) async => [
            file(17, label: 'Menus', total: 4, done: 1),
            file(2813, done: 10),
            file(2814),
          ],
        ),
        fileBudgetsProvider.overrideWith(
          (ref) async => {
            17: budget(17, 4000), // strict
            2813: budget(2813, 4096 + 0), // égal à l'original : strict
            2814: budget(2814, 4100), // > orig, aligné 8192 > slot
          },
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('#17 · Menus'), findsOneWidget);
    expect(find.text('#2813 · string_table_a'), findsOneWidget);
    expect(find.text('1 / 4 traduites'), findsOneWidget);
    expect(find.text('10 / 10 traduites'), findsOneWidget);
    expect(find.byType(BudgetGauge), findsNWidgets(3));
    expect(
      find.textContaining('4000 / 4096 o · marge 96 o · strict'),
      findsOneWidget,
    );
    expect(find.textContaining('dépassé'), findsOneWidget);
    expect(find.byKey(const Key('budget-unavailable')), findsNothing);
  });

  testWidgets('gauge levels follow the budget', (tester) async {
    expect(gaugeLevel(budget(1, 4096)), GaugeLevel.ok);
    expect(gaugeLevel(budget(1, 4097)), GaugeLevel.over);
    const roomy = FileBudget(
      fileId: 1,
      origBytes: 1000,
      slotBytes: 4096,
      rebuiltBytes: 1500,
    );
    expect(gaugeLevel(roomy), GaugeLevel.slotOnly);
  });

  testWidgets('unavailable budgets keep the list and show a banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([
        fileListProvider.overrideWith((ref) async => [file(17)]),
        fileBudgetsProvider.overrideWith(
          (ref) => Future<Map<int, FileBudget>>.error('ISO introuvable'),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('file-17')), findsOneWidget);
    expect(find.byKey(const Key('budget-unavailable')), findsOneWidget);
    expect(find.textContaining('ISO introuvable'), findsOneWidget);
    expect(find.byType(BudgetGauge), findsNothing);
  });

  testWidgets('shows a computing hint while budgets load', (tester) async {
    final never = Completer<Map<int, FileBudget>>();
    await tester.pumpWidget(
      app([
        fileListProvider.overrideWith((ref) async => [file(17)]),
        fileBudgetsProvider.overrideWith((ref) => never.future),
      ]),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Jauge : calcul en cours…'), findsOneWidget);
  });

  testWidgets('an empty project explains how to import', (tester) async {
    await tester.pumpWidget(
      app([
        fileListProvider.overrideWith((ref) async => const <FileProgress>[]),
        fileBudgetsProvider.overrideWith(
          (ref) async => const <int, FileBudget>{},
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun fichier importé'), findsOneWidget);
  });
}
