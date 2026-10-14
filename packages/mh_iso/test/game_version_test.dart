import 'package:mh_binary/mh_binary.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:test/test.dart';

void main() {
  const valid = '''
- id: ULJM05800
  platform: psp
  iso_md5: 8E19A966356A83B8B395957671494BD8
  databin_iso_offset: 0x6D50000
- id: NPJB40001_HD
  platform: ps3
  iso_md5: 8328f5774e3106953a9560a0b18c2d49
  databin_iso_offset: 0x6D60000
''';

  test('parse lit les versions et normalise le MD5', () {
    final r = GameVersionRegistry.parse(valid);
    expect(r.versions, hasLength(2));
    expect(r.versions.first.id, 'ULJM05800');
    expect(r.versions.first.isoMd5, '8e19a966356a83b8b395957671494bd8');
    expect(r.versions.first.databinIsoOffset, 0x6D50000);
  });

  test('byMd5 trouve ou renvoie null', () {
    final r = GameVersionRegistry.parse(valid);
    expect(r.byMd5('8328F5774E3106953A9560A0B18C2D49')?.platform, 'ps3');
    expect(r.byMd5('0' * 32), isNull);
  });

  test('config/game_versions.yaml du dépôt est valide', () {
    final r = GameVersionRegistry.fromFile('../../config/game_versions.yaml');
    expect(r.versions, isNotEmpty);
  });

  for (final bad in <String, String>{
    'racine non liste': 'id: x',
    'md5 invalide': '- {id: a, platform: psp, iso_md5: zz, '
        'databin_iso_offset: 2048}',
    'offset non aligné': '- {id: a, platform: psp, '
        'iso_md5: ${'a' * 32}, databin_iso_offset: 100}',
    'offset absent': '- {id: a, platform: psp, iso_md5: ${'a' * 32}}',
    'id absent': '- {platform: psp, iso_md5: ${'a' * 32}, '
        'databin_iso_offset: 2048}',
  }.entries) {
    test('rejette : ${bad.key}', () {
      expect(
        () => GameVersionRegistry.parse(bad.value),
        throwsA(isA<IsoError>()),
      );
    });
  }
}
