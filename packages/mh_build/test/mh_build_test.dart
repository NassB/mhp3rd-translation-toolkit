import 'package:mh_build/mh_build.dart';
import 'package:test/test.dart';

void main() {
  test('mh_build se charge', () {
    expect(mhBuildPackageName, 'mh_build');
  });
}
