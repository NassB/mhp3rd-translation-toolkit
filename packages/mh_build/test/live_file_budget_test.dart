import 'package:mh_build/mh_build.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:test/test.dart';

import 'support/build_fixtures.dart';

const saved = FileBudget(
  fileId: 1,
  origBytes: 1000,
  slotBytes: 2048,
  rebuiltBytes: 900,
);

void main() {
  test('starts at the saved budget', () {
    final live = LiveFileBudget(saved);
    expect(live.current.rebuiltBytes, 900);
    expect(live.draftCount, 0);
  });

  test('drafts add their length delta, zero delta removes the draft', () {
    final live = LiveFileBudget(saved)
      ..setDraft(10, savedLen: 5, draftLen: 25)
      ..setDraft(11, savedLen: 8, draftLen: 3);
    expect(live.current.rebuiltBytes, 900 + 20 - 5);
    expect(live.draftCount, 2);

    live.setDraft(10, savedLen: 5, draftLen: 5);
    expect(live.current.rebuiltBytes, 900 - 5);
    expect(live.draftCount, 1);
    live.clearDraft(11);
    expect(live.current.rebuiltBytes, 900);
  });

  test('levels follow the live size', () {
    final live = LiveFileBudget(saved)
      ..setDraft(1, savedLen: 0, draftLen: 100); // 1000
    expect(live.current.fitsStrict, isTrue);
    live.setDraft(1, savedLen: 0, draftLen: 101); // 1001
    expect(live.current.fitsStrict, isFalse);
    expect(live.current.fitsSlot, isTrue);
    live.setDraft(1, savedLen: 0, draftLen: 1200);
    expect(live.current.fitsSlot, isFalse);
  });

  test('afterSave folds the saved draft in and keeps the others', () {
    final live = LiveFileBudget(saved)
      ..setDraft(1, savedLen: 5, draftLen: 15) // +10
      ..setDraft(2, savedLen: 4, draftLen: 1); // -3
    final next = live.afterSave(1);
    expect(next.saved.rebuiltBytes, 910);
    expect(next.current.rebuiltBytes, 907);
    expect(next.draftCount, 1);
  });

  test('matches a full recomputation once the translation is saved', () async {
    final db = TdbDatabase.openInMemory();
    addTearDown(db.close);
    final original = model();
    final plain = slotBytesOf(original);
    await importSourceFile(
      db,
      fileId: 1,
      versionId: 'TEST',
      lba: 5,
      slotBytes: 2048,
      origBytes: 2048,
      file: original,
    );
    final repo = TranslationRepository(db, locale: 'fr');
    Future<FileBudget> budget() async => (await computeFileBudgets(
          db: db,
          index: DataBinIndex([entry()]),
          readPlain: (_) => plain,
          locale: 'fr',
          fileIds: [1],
        ))[1]!;

    final before = await budget();
    final slot = (await repo.slots(1)).first; // 'un\ndeux' (7 octets)
    final live = LiveFileBudget(before)
      ..setDraft(
        slot.sourceId,
        savedLen: slot.sourceText.length,
        draftLen: 'Un\ndeuxième'.length + 1, // 'è' = 2 octets UTF-8
      );
    await repo.saveTranslation(
      sourceId: slot.sourceId,
      text: 'Un\ndeuxième',
      status: 'draft',
    );
    expect((await budget()).rebuiltBytes, live.current.rebuiltBytes);
    final next = live.afterSave(slot.sourceId);
    expect(next.saved.rebuiltBytes, live.current.rebuiltBytes);
  });
}
