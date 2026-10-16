import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_studio/app/router.dart';
import 'package:mh_studio/features/build/application/build_providers.dart';
import 'package:mh_studio/features/build/presentation/build_page.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_studio/features/project/application/project_providers.dart';
import 'package:mh_tdb/mh_tdb.dart';

const project = Project(
  dir: 'p',
  isoPath: 'x.iso',
  versionId: 'TEST',
  locale: 'fr',
);

class FakeRunner extends BuildRunner {
  final calls = <String>[];
  BuildSummary? result;
  Object? error;
  Completer<void>? gate;

  @override
  Future<BuildSummary?> build() async => null;

  @override
  Future<void> start({
    required String outPath,
    required BudgetPolicy policy,
    required String minStatus,
    required String profile,
  }) async {
    calls.add('$outPath|${policy.name}|$minStatus|$profile');
    state = const AsyncLoading();
    if (gate != null) await gate!.future;
    state = error != null
        ? AsyncError<BuildSummary?>(error!, StackTrace.empty)
        : AsyncData(result);
  }
}

BuildSummary summary(
  String status, {
  BudgetStatus file = BudgetStatus.ok,
  List<String> errors = const [],
  List<DisplayWarning> warnings = const [],
}) => BuildSummary(
  status: status,
  buildId: 7,
  tdbRevision: 12,
  files: [
    BudgetReport(
      fileId: 17,
      origBytes: 2048,
      rebuiltBytes: 2000,
      slotBytes: 2048,
      policy: BudgetPolicy.strict,
      status: file,
      warnings: warnings,
    ),
  ],
  verifyErrors: errors,
  reportJson: '{}',
  outPath: 'out/x.iso',
);

Widget host(FakeRunner fake, {List<BuildRow> history = const []}) =>
    ProviderScope(
      overrides: [
        currentProjectProvider.overrideWithValue(project),
        buildRunnerProvider.overrideWith(() => fake),
        buildHistoryProvider.overrideWith((ref) async => history),
      ],
      child: const MaterialApp(home: BuildPage()),
    );

Future<void> pickMenu(WidgetTester t, String key, String item) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
  await t.tap(find.text(item).last);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('shows the defaults of a nightly build', (t) async {
    await t.pumpWidget(host(FakeRunner()));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byKey(const Key('build-out'))).controller!.text,
      'out/MHP3.fr.iso',
    );
    expect(find.text('nightly'), findsOneWidget);
    expect(find.text('translated'), findsOneWidget);
    expect(find.text('strict'), findsOneWidget);
    expect(find.text('Aucun build.'), findsOneWidget);
    expect(find.byKey(const Key('slot-note')), findsNothing);
  });

  testWidgets('the release profile requires reviewed translations', (t) async {
    final fake = FakeRunner()..result = summary(BuildStatus.ok);
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await pickMenu(t, 'profile-menu', 'release');
    expect(defaultMinStatus('release'), 'reviewed');
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(fake.calls, ['out/MHP3.fr.iso|strict|reviewed|release']);
  });

  testWidgets('the slot policy shows the whitelist note and is passed on', (
    t,
  ) async {
    final fake = FakeRunner()..result = summary(BuildStatus.ok);
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await pickMenu(t, 'policy-menu', 'slot');
    expect(find.byKey(const Key('slot-note')), findsOneWidget);
    await t.enterText(find.byKey(const Key('build-out')), ' out/custom.iso ');
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(fake.calls, ['out/custom.iso|slot|translated|nightly']);
  });

  testWidgets('a running build shows progress and blocks a second start', (
    t,
  ) async {
    final fake = FakeRunner()
      ..result = summary(BuildStatus.ok)
      ..gate = Completer<void>();
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('run-build')));
    await t.pump();
    expect(find.byKey(const Key('build-progress')), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('run-build'))).onPressed,
      isNull,
    );
    fake.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('build-progress')), findsNothing);
    expect(find.byKey(const Key('build-result')), findsOneWidget);
  });

  testWidgets('display warnings are shown, in French, as not blocking', (
    t,
  ) async {
    const w = DisplayWarning(
      tableIdx: 0,
      slotIdx: 1,
      issue: DisplayIssue(DisplayWarningKind.pxOverflow, 212, max: 196),
    );
    final fake = FakeRunner()
      ..result = summary(BuildStatus.ok, warnings: [w, w]);
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(
      find.textContaining('non bloquants) : largeur dépassée (2)'),
      findsOneWidget,
    );
    expect(find.text('ISO écrit et vérifié'), findsOneWidget);
  });

  testWidgets('no warning line when there is no warning', (t) async {
    final fake = FakeRunner()..result = summary(BuildStatus.ok);
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('display-warnings-17')), findsNothing);
  });

  testWidgets('a successful build shows the report', (t) async {
    final fake = FakeRunner()..result = summary(BuildStatus.ok);
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(find.text('ISO écrit et vérifié'), findsOneWidget);
    expect(find.text('Build #7 · révision 12'), findsOneWidget);
    expect(find.text('ISO : out/x.iso'), findsOneWidget);
    expect(find.textContaining('Fichier 17 : ok (2000/2048 o'), findsOneWidget);
  });

  testWidgets('a budget failure and verification errors are reported', (
    t,
  ) async {
    final fake = FakeRunner()
      ..result = summary(
        BuildStatus.budgetExceeded,
        file: BudgetStatus.slotOverflow,
      );
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(find.text('Budget dépassé : aucun ISO écrit'), findsOneWidget);
    expect(find.textContaining('slotOverflow'), findsOneWidget);
    expect(find.textContaining('ISO : '), findsNothing);

    fake.result = summary(
      BuildStatus.verifyFailed,
      errors: ['file 17: written block differs from the patch'],
    );
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(find.text('Vérification de l’ISO échouée'), findsOneWidget);
    expect(find.textContaining('written block differs'), findsOneWidget);
  });

  testWidgets('an exception from the build is displayed', (t) async {
    final fake = FakeRunner()..error = 'ISO introuvable';
    await t.pumpWidget(host(fake));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('run-build')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('build-error')), findsOneWidget);
    expect(find.textContaining('ISO introuvable'), findsOneWidget);
  });

  testWidgets('the history lists previous builds', (t) async {
    final rows = [
      BuildRow(
        id: 2,
        isoMd5: 'a' * 32,
        tdbRevision: 5,
        toolkitVersion: '0.0.1',
        profile: 'release',
        status: 'ok',
        reportJson: null,
        createdAt: DateTime.utc(2026, 10, 15, 12),
      ),
      BuildRow(
        id: 1,
        isoMd5: 'a' * 32,
        tdbRevision: 3,
        toolkitVersion: '0.0.1',
        profile: 'nightly',
        status: 'budget_exceeded',
        reportJson: null,
        createdAt: DateTime.utc(2026, 10, 14, 9),
      ),
    ];
    await t.pumpWidget(host(FakeRunner(), history: rows));
    await t.pumpAndSettle();
    expect(find.text('#2 · ok'), findsOneWidget);
    expect(find.text('#1 · budget_exceeded'), findsOneWidget);
    expect(find.textContaining('release · révision 5'), findsOneWidget);
  });

  testWidgets('the project page opens the build screen', (t) async {
    final router = buildRouter();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          currentProjectProvider.overrideWithValue(project),
          fileListProvider.overrideWith((ref) async => const <FileProgress>[]),
          fileBudgetsProvider.overrideWith(
            (ref) async => const <int, FileBudget>{},
          ),
          buildRunnerProvider.overrideWith(FakeRunner.new),
          buildHistoryProvider.overrideWith((ref) async => const <BuildRow>[]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(Routes.project);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('open-build')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('run-build')), findsOneWidget);
  });
}
