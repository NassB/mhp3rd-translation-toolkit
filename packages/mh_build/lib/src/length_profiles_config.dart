import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:yaml/yaml.dart';

/// Profils de longueur (docs/ARCHITECTURE.md §8.4).
const String defaultProfiles = 'config/profiles.yaml';

/// Charge `config/profiles.yaml` : `profiles` est une table `id -> {...}` avec
/// `max_px` et `max_lines` (entiers >= 0, 0 : non mesuré), `font_context`
/// (chaîne ou `null`), `paginated` (booléen) et `description`. Si [metrics]
/// est donné, un `font_context` doit y exister. Lève [FormatError] si le
/// fichier est absent ou invalide.
LengthProfiles loadLengthProfiles(String path, {GlyphMetrics? metrics}) {
  final f = File(path);
  if (!f.existsSync()) throw FormatError('profiles not found: $path');
  final Object? doc;
  try {
    doc = loadYaml(f.readAsStringSync());
  } on YamlException catch (e) {
    throw FormatError('invalid $path: ${e.message}');
  }
  if (doc is! YamlMap) throw FormatError('$path must be a YAML mapping');
  final map = doc['profiles'];
  if (map is! YamlMap) {
    throw FormatError('$path: profiles must be a mapping of id to settings');
  }
  final out = <LengthProfile>[];
  for (final entry in map.entries) {
    final id = entry.key;
    final v = entry.value;
    if (id is! String || id.trim().isEmpty) {
      throw FormatError('$path: profile ids must be non-empty strings');
    }
    if (v is! YamlMap) {
      throw FormatError('$path: profile "$id" must be a mapping');
    }
    int count(String key) {
      final x = v[key] ?? 0;
      if (x is! int || x < 0) {
        throw FormatError('$path: profile "$id": $key must be an integer '
            '>= 0');
      }
      return x;
    }

    final font = v['font_context'];
    if (font != null && font is! String) {
      throw FormatError('$path: profile "$id": font_context must be a '
          'string or null');
    }
    if (font != null &&
        metrics != null &&
        metrics.context(font as String) == null) {
      throw FormatError('$path: profile "$id": unknown font_context '
          '"$font"');
    }
    final paginated = v['paginated'] ?? false;
    if (paginated is! bool) {
      throw FormatError('$path: profile "$id": paginated must be true or '
          'false');
    }
    out.add(
      LengthProfile(
        id: id,
        description: '${v['description'] ?? ''}',
        fontContext: font as String?,
        maxPx: count('max_px'),
        maxLines: count('max_lines'),
        paginated: paginated,
      ),
    );
  }
  return LengthProfiles(out);
}
