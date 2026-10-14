import 'package:mh_cli/mh_cli.dart';
import 'package:test/test.dart';

void main() {
  test('mh_cli se charge', () {
    expect(mhCliPackageName, 'mh_cli');
  });
}
