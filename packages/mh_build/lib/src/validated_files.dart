import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:yaml/yaml.dart';

/// Version du toolkit enregistrée dans `build.toolkit_version`.
const String toolkitVersion = '0.0.1';

/// Liste blanche de la politique `slot` (docs/ARCHITECTURE.md §8.2).
const String defaultValidatedFiles = 'config/validated_files.yaml';

/// IDs de `config/validated_files.yaml` : liste YAML d'entiers. Un fichier
/// absent donne une liste vide. Lève [FormatError] si le contenu est invalide.
Set<int> loadValidatedFiles(String path) {
  final f = File(path);
  if (!f.existsSync()) return {};
  final Object? doc;
  try {
    doc = loadYaml(f.readAsStringSync());
  } on YamlException catch (e) {
    throw FormatError('invalid $path: ${e.message}');
  }
  if (doc == null) return {};
  if (doc is! YamlList || doc.any((e) => e is! int)) {
    throw FormatError('$path must be a YAML list of integers');
  }
  return {for (final e in doc) e as int};
}
