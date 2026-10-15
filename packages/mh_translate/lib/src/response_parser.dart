// Analyse tolérante de la réponse d'un modèle (docs/DECISIONS/0006).
//
// Un fournisseur sans sortie structurée peut entourer le JSON de texte ou de
// clôtures Markdown, utiliser un tableau nu, des identifiants textuels ou une
// autre clé que `text`. Rien de cela ne doit perdre des traductions valides ;
// ce qui manque ou déborde est **signalé**, jamais deviné. Aucun texte du
// modèle n'apparaît dans les messages d'erreur.

import 'dart:convert';

import 'batching.dart';
import 'chat_client.dart';

/// Résultat de l'analyse d'une réponse pour un [Batch].
final class ParsedBatch {
  /// Voir les champs.
  ParsedBatch({
    required Map<int, String> translations,
    required List<int> missing,
    required List<int> unexpected,
    required List<int> invalid,
  })  : translations = Map.unmodifiable(translations),
        missing = List.unmodifiable(missing),
        unexpected = List.unmodifiable(unexpected),
        invalid = List.unmodifiable(invalid);

  /// Traductions par identifiant, pour les chaînes du lot seulement.
  final Map<int, String> translations;

  /// Identifiants du lot sans traduction exploitable (absents ou invalides).
  final List<int> missing;

  /// Identifiants reçus qui n'appartiennent pas au lot (ignorés).
  final List<int> unexpected;

  /// Identifiants reçus dont le texte n'est pas une chaîne (comptés aussi
  /// dans [missing]).
  final List<int> invalid;

  /// Vrai si toutes les chaînes du lot ont une traduction.
  bool get complete => missing.isEmpty;
}

/// Extrait le premier objet ou tableau JSON de [text] (clôtures ``` et texte
/// autour tolérés). Retourne `null` si aucun JSON valide n'est trouvé.
Object? extractJson(String text) {
  var start = -1;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c != '{' && c != '[') continue;
    start = i;
    final end = _matchingClose(text, i);
    if (end < 0) continue;
    try {
      return jsonDecode(text.substring(start, end + 1));
    } on FormatException {
      // Pas du JSON (accolade dans du texte) : on essaie la suivante.
    }
  }
  return null;
}

/// Indice de la fermeture qui correspond à l'ouverture en [open], en
/// respectant les chaînes JSON ; -1 si elle manque.
int _matchingClose(String s, int open) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    if (c == '"') {
      inString = true;
    } else if (c == '{' || c == '[') {
      depth++;
    } else if (c == '}' || c == ']') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int? _asId(Object? v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

/// Analyse [content] pour [batch].
///
/// Accepte `{"items":[…]}` ou un tableau nu ; chaque élément porte `id` (entier
/// ou texte numérique) et `text` (ou `translation`). Le premier élément d'un
/// identifiant l'emporte. Lève [TranslateError] (`invalidResponse`) si aucun
/// JSON exploitable n'existe.
ParsedBatch parseTranslations(String content, Batch batch) {
  final json = extractJson(content);
  final List<Object?>? items = switch (json) {
    final List<Object?> l => l,
    final Map<Object?, Object?> m when m['items'] is List =>
      m['items']! as List<Object?>,
    _ => null,
  };
  if (items == null) {
    throw const TranslateError(
      TranslateErrorKind.invalidResponse,
      'no translations array found in the model output',
    );
  }
  final wanted = {for (final u in batch.units) u.id};
  final translations = <int, String>{};
  final unexpected = <int>[];
  final invalid = <int>[];
  final seen = <int>{};
  for (final item in items) {
    if (item is! Map) continue;
    final id = _asId(item['id']);
    if (id == null) continue;
    if (!wanted.contains(id)) {
      if (!unexpected.contains(id)) unexpected.add(id);
      continue;
    }
    if (!seen.add(id)) continue; // doublon : le premier l'emporte
    final text = item['text'] ?? item['translation'];
    if (text is String) {
      translations[id] = text;
    } else {
      invalid.add(id);
    }
  }
  return ParsedBatch(
    translations: translations,
    missing: [
      for (final u in batch.units)
        if (!translations.containsKey(u.id)) u.id,
    ],
    unexpected: unexpected,
    invalid: invalid,
  );
}
