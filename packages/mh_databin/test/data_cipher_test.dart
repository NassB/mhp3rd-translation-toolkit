import 'dart:math';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:test/test.dart';

Uint8List _random(int length, int seed) {
  final rnd = Random(seed);
  return Uint8List.fromList(
    List<int>.generate(length, (_) => rnd.nextInt(256)),
  );
}

void main() {
  const cipher = DataCipher();

  group('round-trip', () {
    test('encrypt(decrypt(x, lba), lba) == x sur blocs aléatoires', () {
      for (final lba in [0, 1, 0x1234, 0xffff, 0x10000, 0x6d50, 0xfffffff]) {
        final x = _random(2048 * 3, lba + 7);
        expect(cipher.encrypt(cipher.decrypt(x, lba), lba), x, reason: '$lba');
        expect(cipher.decrypt(cipher.encrypt(x, lba), lba), x, reason: '$lba');
      }
    });

    test('données vides', () {
      expect(cipher.decrypt(Uint8List(0), 5), isEmpty);
      expect(cipher.encrypt(Uint8List(0), 5), isEmpty);
    });
  });

  group('propriétés', () {
    test('le LBA change le résultat', () {
      final x = _random(64, 1);
      expect(cipher.decrypt(x, 1), isNot(cipher.decrypt(x, 2)));
    });

    test('lba 0 = graine par défaut (0x2345, 0x7f8d)', () {
      // k0 = 0 -> 0x2345 et k1 = 0 -> 0x7f8d : même flux que lba 0x23457f8d.
      final x = _random(64, 2);
      expect(cipher.decrypt(x, 0), cipher.decrypt(x, 0x23457f8d));
    });

    test("n'altère pas l'entrée", () {
      final x = _random(32, 3);
      final copy = Uint8List.fromList(x);
      cipher.decrypt(x, 9);
      cipher.encrypt(x, 9);
      expect(x, copy);
    });

    test('pas de chaînage : un bloc se déchiffre seul', () {
      final x = _random(8, 4);
      final whole = cipher.decrypt(x, 77);
      final head = cipher.decrypt(Uint8List.sublistView(x, 0, 4), 77);
      expect(head, Uint8List.sublistView(whole, 0, 4));
    });
  });

  group('erreurs', () {
    test('longueur non multiple de 4', () {
      expect(
        () => cipher.decrypt(Uint8List(5), 0),
        throwsA(isA<CryptoError>()),
      );
      expect(
        () => cipher.encrypt(Uint8List(2), 0),
        throwsA(isA<CryptoError>()),
      );
    });

    test('LBA hors u32', () {
      expect(
        () => cipher.decrypt(Uint8List(4), -1),
        throwsA(isA<CryptoError>()),
      );
      expect(
        () => cipher.decrypt(Uint8List(4), 0x100000000),
        throwsA(isA<CryptoError>()),
      );
    });
  });

  // Aucun vecteur de référence dans third_party/mhef ni mhtools. Ce vecteur
  // est un test de non-régression généré par ce portage (clé du premier mot à
  // lba 0 calculée à la main : 0xAE1DED19), pas une valeur issue du jeu.
  test('non-régression : 4 octets nuls à lba 0', () {
    final enc = cipher.encrypt(Uint8List(4), 0);
    // Octet 0 recoupé à la main : clé 0xAE1DED19 -> octet 0x19 -> encode[0x19].
    expect(enc, Uint8List.fromList([0xeb, 0xe3, 0x69, 0xa0]));
    expect(cipher.decrypt(enc, 0), Uint8List(4));
  });
}
