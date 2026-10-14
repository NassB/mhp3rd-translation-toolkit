// Copyright 2013-2015 Seth VanHeulen (algorithme et tables d'origine)
//
// Portage Dart de la classe `DataCipher` de mhef (third_party/mhef/mhef/psp.py,
// `_init_key`, `_next_key`, `encrypt`, `decrypt`), recoupée avec
// third_party/mhtools/src/crypt/DecryptUtils.java (Copyright (C) 2011
// Codestation). Voir docs/DECISIONS/0001-licences.md.
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.

import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

/// Chiffrement des blocs de `DATA.BIN` (MHP3, PSP).
///
/// Deux couches, appliquées dans l'ordre inverse au chiffrement :
///
/// 1. substitution octet par octet (table de 256 octets) ;
/// 2. XOR de chaque mot u32 little-endian avec un flux de clés généré à partir
///    du LBA, qui est le numéro de bloc de 2048 octets **dans DATA.BIN**
///    (valeur de la TOC), pas un LBA de l'ISO.
///
/// Flux de clés (source : psp.py `_init_key` / `_next_key`) :
///
/// | Étape      | Calcul                                                    |
/// |------------|-----------------------------------------------------------|
/// | init       | `k0 = lba >> 16` (0 → 0x2345), `k1 = lba & 0xFFFF` (0 → 0x7F8D) |
/// | mot suivant| `k0 = k0·0x2345 mod 0xFFD9`, `k1 = k1·0x7F8D mod 0xFFF1`  |
/// | clé        | `(k0 << 16) + k1`                                         |
///
/// Le TOC est chiffré avec `lba = 0`. Chaque fichier redémarre le flux à son
/// propre LBA (pas de chaînage entre blocs). Les données doivent avoir une
/// longueur multiple de 4.
final class DataCipher {
  /// Crée le chiffreur MHP3 JP.
  const DataCipher();

  static const int _keyDefault0 = 0x2345;
  static const int _keyDefault1 = 0x7f8d;
  static const int _keyModulus0 = 0xffd9;
  static const int _keyModulus1 = 0xfff1;

  /// Table de substitution inverse. Source : psp.py `DataCipher._decode_table`
  /// (identique à mhtools `DataKeys.decrypter_table`).
  static final Uint8List _decodeTable = _hex(
    'cb9685a65f3eab0350b79c5cb240eff6ff611529a2f1ec523528d9682436c474'
    '26e2d58c474d2cfa8666c14f0b815b1bc00afd17a4a96d63adf3f46e8d8914dd'
    '59874a30cefe3f7e0649a5045ed0dee80fd4131fbab969713de4dc5890343a3c'
    'ca1076c7c84533c3921d2b1c8f6f0507385751d6da2db3c62e64321e43b15de1'
    'bb8e9d7277f227c97f9eaa6a2f6cf948e7a00956b8bd2041cd9580d7230c42e5'
    'ae8b7dbc5439bf650188e07bb616184bcc225ab5ebfcf89b4ee6a8be67739794'
    '0062b4d221251182db9302847cd3b0a391a7f755707a08758a5379fb9f46f583'
    'd80ee9ed12d1dff0372a44199a31cfa1afe33b1a4c78c260ee986b0d99eac5ac',
  );

  /// Table de substitution directe. Source : psp.py `DataCipher._encode_table`.
  static final Uint8List _encodeTable = _hex(
    'c0a8ca074b6e486fd692312c9dfbe15061c6e4523e12ad33aeebf32f6b697b53'
    '96c4b19c1cc520861913e96a2675788c43ed7a665d181de870a55ef25f580546'
    '0d979e7cea65dd248f4942aff425b82b087217d9a4d393715b40b22e0b7e4c04'
    'f711c13779a729bc1b568bfa8d363b6dd45783bd1fd76284f5dad5abcca24788'
    '9a2dc7dfcb022841a93dd8a1233c816c5cd068c9bf9901bef9fcecb70a8289dc'
    '91ef14cf344a03d1ba358a06ff38a0f0ce7d0c76c2b3ac0994555480a395bba6'
    '302af6671efe776364876000b09844ee4de5c3cd5122739be01a74c85a3f4ee6'
    'aa7f21f1599fb9904fe2fdb416e3f80ee71585393ade0fd2b68e27dbb5324510',
  );

  static Uint8List _hex(String s) {
    final out = Uint8List(s.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static void _checkInput(Uint8List data, int lba) {
    if (data.length % 4 != 0) {
      throw CryptoError(
        'data length ${data.length} is not a multiple of 4',
        offset: 0,
      );
    }
    if (lba < 0 || lba > 0xffffffff) {
      throw CryptoError('lba $lba out of u32 range');
    }
  }

  /// XOR in situ de [buf] avec le flux de clés de [lba].
  static void _xorKeyStream(Uint8List buf, int lba) {
    var k0 = lba >> 16;
    if (k0 == 0) k0 = _keyDefault0;
    var k1 = lba & 0xffff;
    if (k1 == 0) k1 = _keyDefault1;
    for (var i = 0; i < buf.length; i += 4) {
      k0 = (k0 * _keyDefault0) % _keyModulus0;
      k1 = (k1 * _keyDefault1) % _keyModulus1;
      final key = (k0 << 16) + k1;
      buf[i] ^= key & 0xff;
      buf[i + 1] ^= (key >> 8) & 0xff;
      buf[i + 2] ^= (key >> 16) & 0xff;
      buf[i + 3] ^= (key >> 24) & 0xff;
    }
  }

  /// Retourne une copie déchiffrée de [data] (bloc(s) lu(s) dans DATA.BIN).
  Uint8List decrypt(Uint8List data, int lba) {
    _checkInput(data, lba);
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = _decodeTable[data[i]];
    }
    _xorKeyStream(out, lba);
    return out;
  }

  /// Retourne une copie chiffrée de [data], pour un fichier placé au bloc [lba].
  Uint8List encrypt(Uint8List data, int lba) {
    _checkInput(data, lba);
    final out = Uint8List.fromList(data);
    _xorKeyStream(out, lba);
    for (var i = 0; i < out.length; i++) {
      out[i] = _encodeTable[out[i]];
    }
    return out;
  }
}
