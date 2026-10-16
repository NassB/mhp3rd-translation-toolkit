import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:yaml/yaml.dart';

/// Métriques de glyphes mesurées en jeu (docs/CALIBRATION.md §5).
const String defaultFontMetrics = 'config/font_metrics.yaml';

/// Charge `config/font_metrics.yaml` : `contexts` (liste de `id`,
/// `advance_px` entier > 0, `observed` facultatif), `wide_advance_px`
/// (entier > 0 ou `null`) et `extra_known_chars` (chaîne). Lève
/// [FormatError] si le fichier est absent ou invalide.
GlyphMetrics loadFontMetrics(String path) {
  final f = File(path);
  if (!f.existsSync()) throw FormatError('font metrics not found: $path');
  final Object? doc;
  try {
    doc = loadYaml(f.readAsStringSync());
  } on YamlException catch (e) {
    throw FormatError('invalid $path: ${e.message}');
  }
  if (doc is! YamlMap) throw FormatError('$path must be a YAML mapping');

  final wide = doc['wide_advance_px'];
  if (wide != null && (wide is! int || wide <= 0)) {
    throw FormatError('$path: wide_advance_px must be a positive integer '
        'or null');
  }
  final extra = doc['extra_known_chars'] ?? '';
  if (extra is! String) {
    throw FormatError('$path: extra_known_chars must be a string');
  }
  final list = doc['contexts'];
  if (list is! YamlList || list.isEmpty) {
    throw FormatError('$path: contexts must be a non-empty list');
  }
  final contexts = <FontContext>[];
  final seen = <String>{};
  for (final e in list) {
    if (e is! YamlMap) throw FormatError('$path: a context must be a mapping');
    final id = e['id'];
    final advance = e['advance_px'];
    if (id is! String || id.trim().isEmpty || !seen.add(id)) {
      throw FormatError('$path: context ids must be unique non-empty strings');
    }
    if (advance is! int || advance <= 0) {
      throw FormatError('$path: context "$id": advance_px must be a '
          'positive integer');
    }
    contexts.add(
      FontContext(
        id: id,
        advancePx: advance,
        description: '${e['observed'] ?? ''}',
      ),
    );
  }
  return GlyphMetrics(
    contexts: contexts,
    knownChars: {...measuredLatinChars(), ...extra.runes},
    wideAdvancePx: wide as int?,
  );
}
