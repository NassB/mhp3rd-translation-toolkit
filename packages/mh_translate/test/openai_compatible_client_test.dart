import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mh_translate/mh_translate.dart';
import 'package:test/test.dart';

/// Requête reçue par le faux serveur.
class Seen {
  Seen(this.method, this.path, this.headers, this.json);

  final String method;
  final String path;
  final HttpHeaders headers;
  final Map<String, Object?>? json;
}

typedef Responder = ({int status, Object? body, Duration delay}) Function(
  Seen seen,
);

({int status, Object? body, Duration delay}) ok(
  Object? body, {
  int status = 200,
  Duration delay = Duration.zero,
}) =>
    (status: status, body: body, delay: delay);

/// Serveur HTTP local factice (aucun réseau réel).
class FakeServer {
  FakeServer._(this._server, this._responder) {
    _server.listen((req) async {
      final text = await utf8.decoder.bind(req).join();
      final json = text.isEmpty
          ? null
          : (jsonDecode(text) as Map).cast<String, Object?>();
      final seen = Seen(req.method, req.uri.path, req.headers, json);
      seens.add(seen);
      final r = _responder(seen);
      if (r.delay > Duration.zero) await Future<void>.delayed(r.delay);
      try {
        req.response.statusCode = r.status;
        req.response.headers.contentType = ContentType.json;
        req.response.write(r.body is String ? r.body : jsonEncode(r.body));
        await req.response.close();
      } on Object {
        // Client parti (délai dépassé) : sans importance.
      }
    });
  }

  static Future<FakeServer> start(Responder responder) async => FakeServer._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        responder,
      );

  final HttpServer _server;
  final Responder _responder;
  final seens = <Seen>[];

  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}/v1');

  Future<void> close() => _server.close(force: true);
}

Map<String, Object?> completion(
  String? content, {
  String finish = 'stop',
  Object? usage = const {'prompt_tokens': 37, 'completion_tokens': 12},
  String? reasoning,
}) =>
    {
      'choices': [
        {
          'index': 0,
          'message': {
            'role': 'assistant',
            'content': content,
            if (reasoning != null) 'reasoning_content': reasoning,
          },
          'finish_reason': finish,
        },
      ],
      'usage': usage,
    };

void main() {
  late FakeServer server;
  late OpenAiCompatibleClient client;

  Future<void> up(Responder responder, {bool disableReasoning = true}) async {
    server = await FakeServer.start(responder);
    client = OpenAiCompatibleClient(
      endpoint: server.endpoint,
      disableReasoning: disableReasoning,
      responseTimeout: const Duration(seconds: 5),
    );
  }

  tearDown(() async {
    client.close();
    await server.close();
  });

  const hello = [ChatMessage.system('sys'), ChatMessage.user('usr')];

  test('listModels returns every model id and ignores junk entries', () async {
    await up(
      (_) => ok({
        'data': [
          {'id': 'a/model-1', 'object': 'model'},
          {'id': 'text-embedding-x'},
          {'object': 'model'},
          'junk',
        ],
      }),
    );
    expect(await client.listModels(), ['a/model-1', 'text-embedding-x']);
    expect(server.seens.single.method, 'GET');
    expect(server.seens.single.path, '/v1/models');
  });

  test('chat sends the documented request body', () async {
    await up((_) => ok(completion('Bonjour.')));
    final r = await client.chat(
      model: 'google/gemma',
      messages: hello,
      temperature: 0.3,
      maxTokens: 900,
      jsonSchema: const JsonSchemaFormat(
        name: 'translations',
        schema: {'type': 'object'},
      ),
    );
    final req = server.seens.single;
    expect(req.method, 'POST');
    expect(req.path, '/v1/chat/completions');
    expect(req.headers.contentType?.mimeType, 'application/json');
    expect(req.headers.value('authorization'), isNull);
    final body = req.json!;
    expect(body['model'], 'google/gemma');
    expect(body['temperature'], 0.3);
    expect(body['max_tokens'], 900);
    expect(body['reasoning_effort'], 'none');
    expect(body['messages'], [
      {'role': 'system', 'content': 'sys'},
      {'role': 'user', 'content': 'usr'},
    ]);
    expect(body['response_format'], {
      'type': 'json_schema',
      'json_schema': {
        'name': 'translations',
        'strict': true,
        'schema': {'type': 'object'},
      },
    });
    expect(r.content, 'Bonjour.');
  });

  test('optional fields are omitted and the key is sent only when set',
      () async {
    await up((_) => ok(completion('x')), disableReasoning: false);
    await client.chat(model: 'm', messages: hello);
    final body = server.seens.single.json!;
    expect(body.containsKey('max_tokens'), isFalse);
    expect(body.containsKey('response_format'), isFalse);
    expect(body.containsKey('reasoning_effort'), isFalse);

    final keyed = OpenAiCompatibleClient(
      endpoint: Uri.parse('${server.endpoint}/'), // barre finale tolérée
      apiKey: 'sk-test',
    );
    addTearDown(keyed.close);
    await keyed.chat(model: 'm', messages: hello);
    expect(server.seens.last.path, '/v1/chat/completions');
    expect(server.seens.last.headers.value('authorization'), 'Bearer sk-test');
  });

  test('result carries content, finish reason and usage only', () async {
    await up(
      (_) => ok(completion('Il fait beau.', reasoning: 'SECRET REASONING')),
    );
    final r = await client.chat(model: 'm', messages: hello);
    expect(r.content, 'Il fait beau.');
    expect(r.finishReason, 'stop');
    expect((r.promptTokens, r.completionTokens), (37, 12));
    expect(r.truncated, isFalse);
    expect('${r.content}${r.finishReason}', isNot(contains('SECRET')));
  });

  test('missing usage is fine; a cut but non-empty output is returned',
      () async {
    await up((_) => ok(completion('abc', finish: 'length', usage: null)));
    final r = await client.chat(model: 'm', messages: hello);
    expect(r.truncated, isTrue);
    expect(r.promptTokens, isNull);
  });

  test('empty content: truncated vs empty response', () async {
    await up(
      (_) => ok(completion('', finish: 'length', reasoning: 'ja text')),
    );
    await expectLater(
      client.chat(model: 'm', messages: hello),
      throwsA(
        isA<TranslateError>().having(
          (e) => e.kind,
          'kind',
          TranslateErrorKind.truncated,
        ),
      ),
    );
    client.close();
    await server.close();

    await up((_) => ok(completion(null)));
    await expectLater(
      client.chat(model: 'm', messages: hello),
      throwsA(
        isA<TranslateError>().having(
          (e) => e.kind,
          'kind',
          TranslateErrorKind.emptyResponse,
        ),
      ),
    );
  });

  test('HTTP errors keep the status and a short error code, never the message',
      () async {
    await up(
      (_) => ok(
        {
          'error': {
            'message': 'LEAK: こんにちは the user text',
            'code': 'model_not_found',
          },
        },
        status: 404,
      ),
    );
    final e = await client
        .chat(model: 'm', messages: hello)
        .then<TranslateError?>((_) => null)
        .catchError((Object e) => e as TranslateError);
    expect(e, isNotNull);
    expect(e!.kind, TranslateErrorKind.http);
    expect(e.statusCode, 404);
    expect('$e', contains('HTTP 404 (model_not_found)'));
    expect('$e', isNot(contains('LEAK')));
  });

  test('an unsafe error code is dropped', () async {
    await up(
      (_) => ok(
        {
          'error': {'code': 'こんにちは user text with spaces'},
        },
        status: 500,
      ),
    );
    await expectLater(
      client.chat(model: 'm', messages: hello),
      throwsA(
        isA<TranslateError>()
            .having((e) => '$e', 'text', contains('HTTP 500'))
            .having(
              (e) => '$e',
              'no code',
              isNot(contains('こんにちは')),
            ),
      ),
    );
  });

  test('a server refusing reasoning_effort is retried once without it',
      () async {
    await up(
      (seen) => seen.json!.containsKey('reasoning_effort')
          ? ok(
              {
                'error': {'code': 'unknown_field'},
              },
              status: 400,
            )
          : ok(completion('ok')),
    );
    final r = await client.chat(model: 'm', messages: hello);
    expect(r.content, 'ok');
    expect(server.seens, hasLength(2));
    expect(server.seens.first.json!['reasoning_effort'], 'none');
    expect(server.seens.last.json!.containsKey('reasoning_effort'), isFalse);
  });

  test('a 400 unrelated to reasoning is not retried when disabled', () async {
    await up(
      (_) => ok(<String, Object?>{'error': <String, Object?>{}}, status: 400),
      disableReasoning: false,
    );
    await expectLater(
      client.chat(model: 'm', messages: hello),
      throwsA(isA<TranslateError>()),
    );
    expect(server.seens, hasLength(1));
  });

  test('malformed bodies are invalid responses', () async {
    for (final body in <Object?>[
      'not json',
      {'nothing': true},
      {'choices': <Object?>[]},
      {
        'choices': ['x'],
      },
      {
        'choices': [
          {'finish_reason': 'stop'},
        ],
      },
    ]) {
      await up((_) => ok(body));
      await expectLater(
        client.chat(model: 'm', messages: hello),
        throwsA(
          isA<TranslateError>().having(
            (e) => e.kind,
            'kind',
            TranslateErrorKind.invalidResponse,
          ),
        ),
        reason: '$body',
      );
      client.close();
      await server.close();
    }
    await up((_) => ok({'nodata': 1}));
  });

  test('an unreachable server and a slow server are distinguished', () async {
    final dead = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = dead.port;
    await dead.close();
    final c = OpenAiCompatibleClient(
      endpoint: Uri.parse('http://127.0.0.1:$port/v1'),
    );
    addTearDown(c.close);
    await expectLater(
      c.listModels(),
      throwsA(
        isA<TranslateError>().having(
          (e) => e.kind,
          'kind',
          TranslateErrorKind.unreachable,
        ),
      ),
    );

    server = await FakeServer.start(
      (_) => ok(completion('late'), delay: const Duration(seconds: 2)),
    );
    client = OpenAiCompatibleClient(
      endpoint: server.endpoint,
      responseTimeout: const Duration(milliseconds: 200),
    );
    await expectLater(
      client.chat(model: 'm', messages: hello),
      throwsA(
        isA<TranslateError>().having(
          (e) => e.kind,
          'kind',
          TranslateErrorKind.timeout,
        ),
      ),
    );
  });

  test('isLocalEndpoint', () {
    for (final u in [
      'http://localhost:1235/v1',
      'http://LOCALHOST/v1',
      'http://127.0.0.1:1234/v1',
      'http://[::1]:1234/v1',
      'http://lmstudio.localhost/v1',
    ]) {
      expect(isLocalEndpoint(Uri.parse(u)), isTrue, reason: u);
    }
    for (final u in [
      'https://api.example.com/v1',
      'http://192.168.1.20:1234/v1',
      'http://localhost.evil.com/v1',
      'http://127.0.0.2/v1',
    ]) {
      expect(isLocalEndpoint(Uri.parse(u)), isFalse, reason: u);
    }
  });
}
