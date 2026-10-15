import 'dart:convert';
import 'dart:io';

/// Réglages de pré-traduction d'un projet (`<projet>/ai.json`).
///
/// Ne contient **jamais** de clé d'API (docs/DECISIONS/0006) : une clé éventuelle
/// vient de la variable d'environnement `MHTK_LLM_API_KEY`.
final class AiSettings {
  /// Voir les champs.
  const AiSettings({this.endpoint = defaultEndpoint, this.model});

  /// Adresse par défaut de l'API locale de LM Studio.
  static const String defaultEndpoint = 'http://localhost:1234/v1';

  /// Nom du fichier dans le dossier du projet.
  static const String fileName = 'ai.json';

  final String endpoint;

  /// Identifiant du modèle choisi, `null` tant qu'aucun n'est choisi.
  final String? model;

  AiSettings copyWith({String? endpoint, String? model}) => AiSettings(
        endpoint: endpoint ?? this.endpoint,
        model: model ?? this.model,
      );

  /// Lit les réglages de [projectDir] ; un fichier absent ou illisible donne
  /// les valeurs par défaut (jamais d'exception).
  static AiSettings load(String projectDir) {
    try {
      final f = File('$projectDir/$fileName');
      if (!f.existsSync()) return const AiSettings();
      final j = jsonDecode(f.readAsStringSync());
      if (j is! Map) return const AiSettings();
      final endpoint = j['endpoint'];
      final model = j['model'];
      return AiSettings(
        endpoint: endpoint is String && endpoint.trim().isNotEmpty
            ? endpoint.trim()
            : defaultEndpoint,
        model: model is String && model.trim().isNotEmpty ? model.trim() : null,
      );
    } on Object {
      return const AiSettings();
    }
  }

  /// Écrit les réglages dans [projectDir] (le dossier doit exister).
  void save(String projectDir) =>
      File('$projectDir/$fileName').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
              'endpoint': endpoint,
              'model': model,
            })}\n',
      );
}
