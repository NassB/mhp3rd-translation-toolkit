import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:test/test.dart';

BudgetReport eval(
  int rebuilt, {
  int orig = 3000,
  int slot = 4096,
  BudgetPolicy policy = BudgetPolicy.strict,
  Set<int> allowed = const {},
}) =>
    evaluateFileBudget(
      fileId: 7,
      origBytes: orig,
      rebuiltBytes: rebuilt,
      slotBytes: slot,
      policy: policy,
      slotAllowedFileIds: allowed,
    );

void main() {
  group('strict', () {
    test('ok when <= original, including equality', () {
      expect(eval(3000).status, BudgetStatus.ok);
      expect(eval(10).status, BudgetStatus.ok);
      expect(eval(0).isOk, isTrue);
    });

    test('larger than original but within slot is blocked', () {
      expect(eval(3001).status, BudgetStatus.bufferOverflow);
    });

    test('aligned size above slot is a level 1 overflow', () {
      // 4096 < 4097 -> aligné 6144 > 4096
      final r = eval(4097, orig: 5000);
      expect(r.status, BudgetStatus.slotOverflow);
      expect(r.alignedBytes, 6144);
    });
  });

  group('slot', () {
    test('refused outside the whitelist', () {
      expect(
        eval(3500, policy: BudgetPolicy.slot).status,
        BudgetStatus.policyNotAllowed,
      );
    });

    test('allows growth up to the slot for whitelisted files', () {
      final ok = eval(4096, policy: BudgetPolicy.slot, allowed: {7});
      expect(ok.status, BudgetStatus.ok);
      final over = eval(4097, policy: BudgetPolicy.slot, allowed: {7});
      expect(over.status, BudgetStatus.slotOverflow);
    });

    test('alignment applies: 4095 bytes fit a 4096 slot', () {
      expect(
        eval(4095, policy: BudgetPolicy.slot, allowed: {7}).isOk,
        isTrue,
      );
    });

    test('unaligned slot rejects sizes whose alignment overflows', () {
      // slot de 3000 (non multiple du secteur) : 3000 -> aligné 4096 > 3000.
      expect(
        eval(3000, slot: 3000, policy: BudgetPolicy.slot, allowed: {7}).status,
        BudgetStatus.slotOverflow,
      );
    });
  });

  group('requireOk', () {
    test('does nothing when ok', () => eval(100).requireOk());

    test('throws BudgetError with level and sizes', () {
      expect(
        () => eval(3001).requireOk(),
        throwsA(
          isA<BudgetError>()
              .having((e) => e.level, 'level', BudgetLevel.buffer)
              .having((e) => e.actualBytes, 'actual', 3001)
              .having((e) => e.limitBytes, 'limit', 3000)
              .having((e) => e.fileId, 'fileId', 7),
        ),
      );
      expect(
        () => eval(4097, orig: 5000).requireOk(),
        throwsA(
          isA<BudgetError>()
              .having((e) => e.level, 'level', BudgetLevel.slot)
              .having((e) => e.actualBytes, 'actual', 6144)
              .having((e) => e.limitBytes, 'limit', 4096),
        ),
      );
    });

    test('whitelist violation is a PatchError', () {
      expect(
        () => eval(100, policy: BudgetPolicy.slot).requireOk(),
        throwsA(isA<PatchError>()),
      );
    });
  });

  test('toJson matches the report format', () {
    expect(eval(2500).toJson(), {
      'file_id': 7,
      'orig_bytes': 3000,
      'rebuilt_bytes': 2500,
      'slot_bytes': 4096,
      'policy': 'strict',
      'status': 'ok',
      'warnings': <Object>[],
    });
  });
}
