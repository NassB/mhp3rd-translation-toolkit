import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

/// Table 0 : 'a', '', alias de 0, '日本' ; table 1 nulle ; table 2 vide ;
/// table 3 : 'xyz'. endData de 5 octets.
StringTableFile model(List<List<Uint8List>?> raws) {
  final aliasOf = {
    0: {2: 0},
  };
  return StringTableFile(
    unknownHeader: 8,
    tables: [
      for (var j = 0; j < raws.length; j++)
        raws[j] == null
            ? null
            : StringTable(
                originalOffsets: const [],
                slots: [
                  for (var i = 0; i < raws[j]!.length; i++)
                    StringSlot(
                      index: i,
                      raw: raws[j]![i],
                      aliasOf: aliasOf[j]?[i],
                    ),
                ],
              ),
    ],
    endData: Uint8List.fromList([1, 2, 3, 4, 5]),
  );
}

List<List<Uint8List>?> initial() => [
      [b('a'), b(''), b('a'), b('日本')],
      null,
      [],
      [b('xyz')],
    ];

void main() {
  test('starts at the exact measured size', () {
    final raws = initial();
    final f = model(raws);
    final t = FileBudgetTracker(f);
    expect(t.rebuiltBytes, measureStringTableA(f));
    expect(t.rebuiltBytes, encodeStringTableA(f).length);
    expect(t.lengthOf(0, 3), 6);
  });

  test('every edit keeps rebuiltBytes == measure == encode().length', () {
    final rnd = Random(20261015);
    final raws = initial();
    final t = FileBudgetTracker(model(raws));
    // Slots modifiables (non alias, table non nulle).
    final slots = <(int, int)>[(0, 0), (0, 1), (0, 3), (3, 0)];
    const alphabet = ['a', 'é', '日', '~', '\n', 'Z'];
    for (var n = 0; n < 300; n++) {
      final (j, i) = slots[rnd.nextInt(slots.length)];
      final len = rnd.nextInt(30);
      final text =
          [for (var k = 0; k < len; k++) alphabet[rnd.nextInt(6)]].join();
      raws[j]![i] = b(text);
      final size = t.setText(j, i, text);
      final f = model(raws);
      expect(size, measureStringTableA(f), reason: 'step $n');
      expect(t.rebuiltBytes, encodeStringTableA(f).length, reason: 'step $n');
    }
  });

  test('setBytes equals setText and returns the new size', () {
    final t = FileBudgetTracker(model(initial()));
    final before = t.rebuiltBytes;
    expect(t.setBytes(3, 0, b('ab')), before - 1);
    expect(t.setText(3, 0, 'xyz'), before);
  });

  test('rejects alias, null table, bad index and NUL', () {
    final t = FileBudgetTracker(model(initial()), fileId: 9);
    final before = t.rebuiltBytes;
    for (final call in <void Function()>[
      () => t.setText(0, 2, 'x'), // alias
      () => t.setText(1, 0, 'x'), // table nulle
      () => t.setText(2, 0, 'x'), // table vide
      () => t.setText(7, 0, 'x'),
      () => t.setText(0, -1, 'x'),
      () => t.setBytes(0, 0, Uint8List.fromList([0x61, 0])),
    ]) {
      expect(call, throwsA(isA<FormatError>()));
    }
    expect(t.rebuiltBytes, before);
  });

  test('report and margin follow the policy', () {
    final f = model(initial());
    final t = FileBudgetTracker(f, fileId: 7);
    final orig = encodeStringTableA(f).length; // 2048 à remplir plus tard
    expect(t.marginBytes(origBytes: orig, slotBytes: 2048), 0);
    expect(
      t.marginBytes(
        origBytes: orig,
        slotBytes: 2048,
        policy: BudgetPolicy.slot,
      ),
      2048 - orig,
    );
    expect(t.report(origBytes: orig, slotBytes: 2048).isOk, isTrue);

    t.setText(0, 0, 'longer text');
    expect(t.marginBytes(origBytes: orig, slotBytes: 2048), lessThan(0));
    final r = t.report(origBytes: orig, slotBytes: 2048);
    expect(r.fileId, 7);
    expect(r.status, BudgetStatus.bufferOverflow);

    t.setText(0, 0, 'x' * 3000);
    expect(
      t.report(origBytes: orig, slotBytes: 2048).status,
      BudgetStatus.slotOverflow,
    );
  });
}
