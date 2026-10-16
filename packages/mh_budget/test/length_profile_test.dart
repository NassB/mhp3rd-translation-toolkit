import 'package:mh_budget/mh_budget.dart';
import 'package:test/test.dart';

void main() {
  test('a profile with no measured limit constrains nothing', () {
    const p = LengthProfile(id: 'menu_label');
    expect((p.checksWidth, p.checksLines, p.hasLimits), (false, false, false));
    expect(p.maxPx, 0);
    expect(p.paginated, isFalse);
  });

  test('width needs both a limit and a known font', () {
    expect(
      const LengthProfile(id: 'a', maxPx: 200).checksWidth,
      isFalse,
      reason: 'limit without font: no check',
    );
    expect(
      const LengthProfile(id: 'a', fontContext: 'px7').checksWidth,
      isFalse,
      reason: 'font without limit: no check',
    );
    const ok = LengthProfile(id: 'a', maxPx: 200, fontContext: 'px7');
    expect((ok.checksWidth, ok.hasLimits), (true, true));
  });

  test('lines are checked as soon as a limit is set', () {
    const p = LengthProfile(id: 'a', maxLines: 3, paginated: true);
    expect((p.checksLines, p.checksWidth, p.hasLimits), (true, false, true));
  });

  test('profiles are indexed, ordered and unique', () {
    final ps = LengthProfiles(const [
      LengthProfile(id: 'b'),
      LengthProfile(id: 'a', maxLines: 1),
    ]);
    expect(ps.ids, {'a', 'b'});
    expect([for (final p in ps.all) p.id], ['b', 'a']);
    expect(ps['a']!.maxLines, 1);
    expect(ps['zz'], isNull);
    expect(
      () => LengthProfiles(
        const [LengthProfile(id: 'a'), LengthProfile(id: 'a')],
      ),
      throwsArgumentError,
    );
  });
}
