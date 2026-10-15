// Client HTTP pour les API « chat completions » compatibles OpenAI (LM Studio
// en local d'abord). Voir docs/DECISIONS/0006-pretraduction-ia.md : mesures du
// 2026-10-15 sur LM Studio (port 1235 sur la machine de référence, modèle
// raisonnant, `reasoning_effort: "none"`, sortie `json_schema`).
//
// Aucune dépendance : `dart:io` seulement. Rien n'est journalisé.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'chat_client.dart';

/// [ChatClient] pour un serveur compatible OpenAI.
final class OpenAiCompatibleClient implements ChatClient {
  /// [endpoint] : racine de l'API, par exemple `http://localhost:1235/v1`
  /// (l'adresse réelle est affichée par LM Studio). [apiKey] n'est envoyée
  /// que si elle est fournie. [disableReasoning] ajoute `reasoning_effort:
  /// "none"` (sinon un modèle raisonnant consomme `max_tokens` et rend un
  /// contenu vide) ; un serveur qui refuse ce champ (HTTP 400 ou 422) est
  /// retenté **une fois** sans lui. [responseTimeout] couvre l'attente de la
  /// réponse complète : le premier appel peut charger le modèle (≈ 30 s
  /// mesurées), d'où une valeur par défaut large.
  OpenAiCompatibleClient({
    required this.endpoint,
    this.apiKey,
    this.disableReasoning = true,
    this.connectTimeout = const Duration(seconds: 10),
    this.responseTimeout = const Duration(seconds: 180),
    HttpClient? httpClient,
  }) : _http = (httpClient ?? HttpClient())..connectionTimeout = connectTimeout;

  final Uri endpoint;
  final String? apiKey;
  final bool disableReasoning;
  final Duration connectTimeout;
  final Duration responseTimeout;
  final HttpClient _http;

  /// Ferme les connexions ouvertes.
  void close() => _http.close(force: true);

  Uri _url(String path) {
    final base = endpoint.path.endsWith('/')
        ? endpoint.path.substring(0, endpoint.path.length - 1)
        : endpoint.path;
    return endpoint.replace(path: '$base/$path');
  }

  @override
  Future<List<String>> listModels() async {
    final r = await _send('GET', _url('models'));
    _expectOk(r);
    final data = _asMap(r.json)?['data'];
    if (data is! List) {
      throw const TranslateError(
        TranslateErrorKind.invalidResponse,
        'models list has no "data" array',
      );
    }
    return [
      for (final m in data)
        if (m is Map && m['id'] is String) m['id']! as String,
    ];
  }

  @override
  Future<ChatResult> chat({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.2,
    int? maxTokens,
    JsonSchemaFormat? jsonSchema,
  }) async {
    Map<String, Object?> body(bool withReasoning) => {
          'model': model,
          'messages': [for (final m in messages) m.toJson()],
          'temperature': temperature,
          if (maxTokens != null) 'max_tokens': maxTokens,
          if (withReasoning) 'reasoning_effort': 'none',
          if (jsonSchema != null) 'response_format': jsonSchema.toJson(),
        };

    var r = await _send(
      'POST',
      _url('chat/completions'),
      body: body(disableReasoning),
    );
    if (disableReasoning && (r.status == 400 || r.status == 422)) {
      r = await _send('POST', _url('chat/completions'), body: body(false));
    }
    _expectOk(r);
    return _parseChat(r.json);
  }

  ChatResult _parseChat(Object? json) {
    const invalid = TranslateError(
      TranslateErrorKind.invalidResponse,
      'unexpected chat completion format',
    );
    final choices = _asMap(json)?['choices'];
    if (choices is! List || choices.isEmpty) throw invalid;
    final choice = _asMap(choices.first);
    if (choice == null) throw invalid;
    final message = _asMap(choice['message']);
    if (message == null) throw invalid;
    final finish = choice['finish_reason'] is String
        ? choice['finish_reason']! as String
        : 'stop';
    // Seul `content` est lu : `reasoning_content` recopie le texte source.
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw TranslateError(
        finish == 'length'
            ? TranslateErrorKind.truncated
            : TranslateErrorKind.emptyResponse,
        finish == 'length'
            ? 'output cut by the token limit before any content '
                '(raise max_tokens or disable reasoning)'
            : 'the model returned no content',
      );
    }
    final usage = _asMap(_asMap(json)?['usage']);
    return ChatResult(
      content: content,
      finishReason: finish,
      promptTokens: _asInt(usage?['prompt_tokens']),
      completionTokens: _asInt(usage?['completion_tokens']),
    );
  }

  void _expectOk(_Reply r) {
    if (r.status >= 200 && r.status < 300) return;
    // Seuls un code HTTP et un identifiant d'erreur court sont repris :
    // le message du serveur pourrait recopier le texte envoyé.
    final err = _asMap(_asMap(r.json)?['error']);
    final code = err?['code'] ?? err?['type'];
    final tag =
        code is String && RegExp(r'^[A-Za-z0-9_.\-]{1,40}$').hasMatch(code)
            ? ' ($code)'
            : '';
    throw TranslateError(
      TranslateErrorKind.http,
      'HTTP ${r.status}$tag',
      statusCode: r.status,
    );
  }

  Future<_Reply> _send(
    String method,
    Uri url, {
    Map<String, Object?>? body,
  }) async {
    try {
      return await _roundTrip(method, url, body).timeout(responseTimeout);
    } on TimeoutException {
      throw const TranslateError(
        TranslateErrorKind.timeout,
        'the server did not answer in time',
      );
    } on SocketException {
      throw const TranslateError(
        TranslateErrorKind.unreachable,
        'cannot reach the server (is it running, and is the port right?)',
      );
    } on HttpException {
      throw const TranslateError(
        TranslateErrorKind.unreachable,
        'HTTP connection failed',
      );
    }
  }

  Future<_Reply> _roundTrip(
    String method,
    Uri url,
    Map<String, Object?>? body,
  ) async {
    final request = await _http.openUrl(method, url);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    if (apiKey != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    }
    if (body != null) {
      final bytes = utf8.encode(jsonEncode(body));
      request.contentLength = bytes.length;
      request.add(bytes);
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      json = null;
    }
    return _Reply(response.statusCode, json);
  }

  static Map<String, Object?>? _asMap(Object? o) =>
      o is Map ? o.cast<String, Object?>() : null;

  static int? _asInt(Object? o) => o is int ? o : null;
}

final class _Reply {
  const _Reply(this.status, this.json);

  final int status;
  final Object? json;
}
