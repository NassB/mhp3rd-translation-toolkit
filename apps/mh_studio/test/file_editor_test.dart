import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_studio/features/editor/application/file_editor.dart';
import 'package:mh_studio/features/editor/application/file_editor_state.dart';
import 'package:mh_studio/features/files/application/files_providers.dart';
import 'package:mh_tdb/mh_tdb.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

// Fichier 17 : 'un\ndeux' (7 o), 'trois' (5 o), alias du premier.
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
  rebuiltBytes: 2000,
);

void main() {
  late TdbDatabase db;
  late TranslationRepository repo;
  late ProviderContainer container;
  late int firstId;
  late int secondId;
  late int aliasId;

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
    final slots = await repo.slots(17);
    firstId = slots[0].sourceId;
    secondId = slots[1].sourceId;
    aliasId = slots[2].sourceId;
    container = ProviderContainer(
      overrides: [
        translationRepositoryProvider.overrideWithValue(repo),
        fileBudgetsProvider.overrideWith((ref) async => {17: baseBudget}),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(() => db.close());

  FileEditor editor() => container.read(fileEditorProvider(17).notifier);
  FileEditorState state() =>
      container.read(fileEditorProvider(17)).requireValue;

  /// Ouvre l'éditeur et attend le budget enregistré.
  Future<void> open() async {
    container.listen(
      fileEditorProvider(17),
      (_, _) {},
    ); // garde le provider en vie
    await container.read(fileEditorProvider(17).future);
    for (var i = 0; i < 50 && state().liveBudget == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(state().liveBudget, isNotNull);
  }

  Future<void> debounce() =>
      Future<void>.delayed(budgetDebounce + const Duration(milliseconds: 80));

  test('loads all slots and the saved budget', () async {
    await open();
    expect(state().slots, hasLength(3));
    expect(state().slots[2].isAlias, isTrue);
    expect(state().liveBudget!.rebuiltBytes, 2000);
    expect(state().budgetError, isNull);
  });

  test(
    'a draft moves the live budget after the debounce, in UTF-8 bytes',
    () async {
      await open();
      editor().setDraft(firstId, text: 'Un\ndeuxième'); // 12 octets - 7 = +5
      expect(state().isDirty(firstId), isTrue);
      expect(state().liveBudget!.rebuiltBytes, 2000); // pas encore publié
      await debounce();
      expect(state().liveBudget!.rebuiltBytes, 2005);

      editor().setDraft(firstId, text: 'x' * 60); // +53 -> 2053 > 2048
      await debounce();
      final live = state().liveBudget!;
      expect(live.rebuiltBytes, 2053);
      expect(live.fitsStrict, isFalse);
      expect(live.fitsSlot, isFalse);
    },
  );

  test(
    'going back to the saved text removes the draft and the delta',
    () async {
      await open();
      editor().setDraft(secondId, text: 'cinq !!');
      await debounce();
      expect(state().liveBudget!.rebuiltBytes, 2002);
      editor().setDraft(secondId, text: '');
      await debounce();
      expect(state().isDirty(secondId), isFalse);
      expect(state().liveBudget!.rebuiltBytes, 2000);
    },
  );

  test('aliases cannot be edited', () async {
    await open();
    editor().setDraft(aliasId, text: 'nope');
    expect(state().drafts, isEmpty);
  });

  test(
    'save stores the translation, folds the budget and patches it',
    () async {
      await open();
      editor().setDraft(firstId, text: 'UN', status: 'translated'); // -5
      expect(await editor().save(firstId, authorId: 'u1'), isTrue);

      final s = state();
      expect(s.drafts, isEmpty);
      expect(s.slot(firstId).translation!.text, 'UN');
      expect(s.slot(firstId).translation!.revision, 1);
      expect(s.liveBudget!.rebuiltBytes, 1995);
      expect(container.read(budgetPatchesProvider)[17]!.rebuiltBytes, 1995);
      final stored = await repo.slots(17);
      expect(stored.first.translation!.authorId, 'u1');
    },
  );

  test('a status-only change on an existing translation is saved', () async {
    await open();
    editor().setDraft(secondId, text: 'cinq', status: 'draft');
    await editor().save(secondId);
    editor().setDraft(secondId, status: 'reviewed');
    expect(state().isDirty(secondId), isTrue);
    expect(await editor().save(secondId), isTrue);
    expect(state().slot(secondId).translation!.status, 'reviewed');
    expect(state().slot(secondId).translation!.revision, 2);
  });

  test(
    'a stale save is a conflict; adopting takes the other version',
    () async {
      await open();
      editor().setDraft(firstId, text: 'MIEN');
      // Un autre traducteur enregistre avant nous.
      await repo.saveTranslation(
        sourceId: firstId,
        text: 'LEUR',
        status: 'translated',
      );
      expect(await editor().save(firstId), isFalse);
      expect(state().conflicts[firstId]!.text, 'LEUR');
      expect(state().isDirty(firstId), isTrue); // le brouillon est conservé

      editor().adoptConflict(firstId);
      expect(state().conflicts, isEmpty);
      expect(state().drafts, isEmpty);
      expect(state().slot(firstId).translation!.text, 'LEUR');
      // Enregistrer à nouveau part de la bonne révision.
      editor().setDraft(firstId, text: 'FINAL');
      expect(await editor().save(firstId), isTrue);
    },
  );

  test(
    'discard drops the draft; saving without a draft does nothing',
    () async {
      await open();
      expect(await editor().save(firstId), isFalse);
      editor().setDraft(firstId, text: 'x');
      editor().discard(firstId);
      expect(state().drafts, isEmpty);
      await debounce();
      expect(state().liveBudget!.rebuiltBytes, 2000);
    },
  );

  test('without a computed budget the editor still works', () async {
    final failing = ProviderContainer(
      overrides: [
        translationRepositoryProvider.overrideWithValue(repo),
        fileBudgetsProvider.overrideWith(
          (ref) => Future<Map<int, FileBudget>>.error('ISO introuvable'),
        ),
      ],
    );
    addTearDown(failing.dispose);
    failing.listen(fileEditorProvider(17), (_, _) {});
    await failing.read(fileEditorProvider(17).future);
    FileEditorState current() =>
        failing.read(fileEditorProvider(17)).requireValue;
    for (var i = 0; i < 50 && current().budgetError == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(current().liveBudget, isNull);
    expect(current().budgetError, contains('ISO introuvable'));
    final notifier = failing.read(fileEditorProvider(17).notifier)
      ..setDraft(firstId, text: 'a');
    expect(await notifier.save(firstId), isTrue);
  });
}
