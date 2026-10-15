// Jetons du texte d'une chaîne de `string_table_a`.
//
// Sources : docs/FORMATS/string_table_a.md (charset UTF-8) ; mhtools
// ExtractPluginA.java (`extract`) ne traite que `\n` (`<NEWLINE>`). Les
// données réelles (711 fichiers détectés, 15 051 slots, explore-data
// 2026-10-15) ne contiennent aucun autre octet de contrôle : aucun code n'est
// inventé ici (AGENTS.md §4.1). Tout autre caractère reste du texte.

import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';

/// Un jeton : [TextToken] ou [NewlineToken].
sealed class Token {
  const Token();
}

/// Texte sans saut de ligne (jamais vide dans une liste canonique).
final class TextToken extends Token {
  /// Voir les champs.
  const TextToken(this.text);

  /// Texte brut.
  final String text;

  @override
  bool operator ==(Object other) => other is TextToken && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Saut de ligne (`0x0A`).
final class NewlineToken extends Token {
  /// Voir les champs.
  const NewlineToken();

  @override
  bool operator ==(Object other) => other is NewlineToken;

  @override
  int get hashCode => 0x0A;
}

/// Découpe [raw] (UTF-8, sans `\0`) en jetons canoniques.
///
/// Lève [FormatError] si [raw] n'est pas de l'UTF-8 valide.
List<Token> tokenizeText(Uint8List raw, {int? fileId}) {
  final String text;
  try {
    text = const Utf8Decoder().convert(raw);
  } on FormatException catch (e) {
    throw FormatError(
      'string is not valid UTF-8',
      offset: e.offset ?? 0,
      fileId: fileId,
    );
  }
  final tokens = <Token>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) != 0x0A) continue;
    if (i > start) tokens.add(TextToken(text.substring(start, i)));
    tokens.add(const NewlineToken());
    start = i + 1;
  }
  if (start < text.length) tokens.add(TextToken(text.substring(start)));
  return tokens;
}

/// Réassemble des jetons en octets UTF-8.
///
/// Lève [FormatError] si un [TextToken] contient `\n` ou `\0` (il fausserait
/// l'encodage ou terminerait la chaîne).
Uint8List detokenizeText(List<Token> tokens, {int? fileId}) {
  final out = BytesBuilder(copy: false);
  for (final t in tokens) {
    switch (t) {
      case NewlineToken():
        out.addByte(0x0A);
      case TextToken(:final text):
        if (text.contains('\n') || text.contains('\u0000')) {
          throw FormatError(
            'text token contains newline or NUL',
            offset: 0,
            fileId: fileId,
          );
        }
        out.add(utf8.encode(text));
    }
  }
  return out.takeBytes();
}

/// Longueur en octets de [tokens] une fois encodés (sans le `\0` final).
///
/// Égale à `detokenizeText(tokens).length`, sans allouer.
int tokensByteLength(List<Token> tokens) {
  var n = 0;
  for (final t in tokens) {
    switch (t) {
      case NewlineToken():
        n += 1;
      case TextToken(:final text):
        n += utf8.encode(text).length;
    }
  }
  return n;
}
