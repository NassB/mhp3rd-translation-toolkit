// Client de chat pour la pré-traduction (docs/DECISIONS/0006-pretraduction-ia.md).
//
// Règles de confidentialité (AGENTS.md §4.2) : ce paquet ne journalise ni les
// corps de requête ni les corps de réponse, ne lit jamais `reasoning_content`
// (il recopie le texte source) et n'insère jamais de contenu du serveur dans
// ses messages d'erreur.

import 'package:mh_binary/mh_binary.dart';

/// Un message d'une conversation.
final class ChatMessage {
  /// Voir les champs.
  const ChatMessage(this.role, this.content);

  /// Message système (consigne).
  const ChatMessage.system(String content) : this('system', content);

  /// Message de l'utilisateur.
  const ChatMessage.user(String content) : this('user', content);

  /// `system`, `user` ou `assistant`.
  final String role;
  final String content;

  /// Forme JSON de l'API.
  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

/// Format de sortie JSON contraint (`response_format` de type `json_schema`).
final class JsonSchemaFormat {
  /// Voir les champs.
  const JsonSchemaFormat({
    required this.name,
    required this.schema,
    this.strict = true,
  });

  final String name;

  /// Schéma JSON de la réponse.
  final Map<String, Object?> schema;
  final bool strict;

  /// Forme JSON de l'API.
  Map<String, Object?> toJson() => {
        'type': 'json_schema',
        'json_schema': {'name': name, 'strict': strict, 'schema': schema},
      };
}

/// Réponse d'un modèle. Ne contient **que** le contenu final : jamais le
/// raisonnement du modèle.
final class ChatResult {
  /// Voir les champs.
  const ChatResult({
    required this.content,
    required this.finishReason,
    this.promptTokens,
    this.completionTokens,
  });

  /// Texte de `choices[0].message.content` (non vide).
  final String content;

  /// `stop`, `length`… tel que renvoyé par le serveur.
  final String finishReason;

  /// Jetons du prompt et de la sortie, si le serveur les donne (`usage`).
  final int? promptTokens;
  final int? completionTokens;

  /// Vrai si la sortie a été coupée par `max_tokens`.
  bool get truncated => finishReason == 'length';
}

/// Nature d'un [TranslateError].
enum TranslateErrorKind {
  /// Serveur injoignable (refus de connexion, hôte inconnu).
  unreachable,

  /// Délai dépassé.
  timeout,

  /// Réponse HTTP d'erreur ([TranslateError.statusCode]).
  http,

  /// Réponse qui n'est pas au format attendu.
  invalidResponse,

  /// Réponse sans contenu.
  emptyResponse,

  /// Sortie coupée par la limite de jetons, sans contenu exploitable.
  truncated,
}

/// Erreur du client de chat. Le message ne contient jamais de contenu du
/// serveur (qui pourrait recopier le texte du jeu).
final class TranslateError extends MhError {
  /// Voir les champs.
  const TranslateError(this.kind, super.message, {this.statusCode});

  final TranslateErrorKind kind;

  /// Code HTTP pour [TranslateErrorKind.http].
  final int? statusCode;
}

/// Fournisseur de complétions de chat (LM Studio, autre service compatible).
abstract interface class ChatClient {
  /// Envoie [messages] à [model] et retourne la réponse finale.
  ///
  /// [maxTokens] borne la sortie ; [jsonSchema] contraint le format. Lève
  /// [TranslateError] en cas d'échec.
  Future<ChatResult> chat({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    JsonSchemaFormat? jsonSchema,
  });

  /// Identifiants des modèles exposés par le serveur (chargés ou non).
  Future<List<String>> listModels();
}

/// Vrai si [endpoint] désigne cette machine (`localhost`, `127.0.0.1`,
/// `[::1]`, `*.localhost`). Tout autre hôte est « distant » : l'envoi du texte
/// du jeu y exige une confirmation explicite.
bool isLocalEndpoint(Uri endpoint) {
  final host = endpoint.host.toLowerCase();
  return host == 'localhost' ||
      host.endsWith('.localhost') ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '[::1]';
}
