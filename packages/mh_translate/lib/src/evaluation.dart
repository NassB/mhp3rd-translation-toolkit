// Outils d'évaluation de la qualité d'un modèle (TA7, docs/QA_PRETRADUCTION.md).
//
// L'humain ne lit pas le japonais : on combine (1) des mesures automatiques
// (contrôles du linter, octets), (2) un « juge » — un autre modèle note la
// fidélité d'une traduction par rapport à sa source —, et (3) une
// rétro-traduction (français → japonais) comparée à la source par similarité
// de trigrammes. Ces mesures sont des **indices**, pas une vérité : elles
// servent à comparer des modèles entre eux et à repérer les cas à relire.
//
// Les messages ci-dessous contiennent du texte du jeu : ils ne sont envoyés
// qu'au serveur choisi et jamais journalisés ni affichés.

import 'dart:convert';

import 'package:mh_tdb/mh_tdb.dart' show similarity;

import 'batching.dart';
import 'chat_client.dart';
import 'prompt.dart';
import 'response_parser.dart';

/// Motifs de défaut relevés par le juge.
const List<String> judgeIssueKinds = [
  'omission',
  'addition',
  'contresens',
  'terme_non_traduit',
  'registre',
  'fluidite',
  'aucun',
];

/// Une paire à juger.
final class JudgeItem {
  /// Voir les champs.
  const JudgeItem({
    required this.id,
    required this.source,
    required this.translation,
  });

  final int id;

  /// Texte japonais d'origine.
  final String source;

  /// Traduction à noter.
  final String translation;
}

/// Note d'une traduction.
final class JudgeScore {
  /// Voir les champs.
  const JudgeScore(this.score, this.issues);

  /// 1 (inutilisable) à 5 (fidèle et naturelle).
  final int score;

  /// Défauts relevés, parmi [judgeIssueKinds].
  final List<String> issues;
}

/// Schéma JSON de la réponse du juge.
JsonSchemaFormat judgeSchema() => const JsonSchemaFormat(
      name: 'judgements',
      schema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
                'score': {'type': 'integer'},
                'issues': {
                  'type': 'array',
                  'items': {'type': 'string', 'enum': judgeIssueKinds},
                },
              },
              'required': ['id', 'score', 'issues'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      },
    );

/// Messages demandant au juge de noter chaque paire de [items].
List<ChatMessage> buildJudgeMessages(
  List<JudgeItem> items, {
  String gameContext =
      'Monster Hunter Portable 3rd (jeu vidéo PSP de chasse aux monstres)',
}) =>
    [
      ChatMessage.system(
        [
          'Tu es un relecteur bilingue japonais-français pour le jeu $gameContext.',
          'Tu reçois un objet JSON avec une liste "items" : chacun a un "id", un '
              '"source" (japonais) et une "translation" (français).',
          'Pour chaque item, note la fidélité et la qualité de la traduction par '
              'un entier "score" de 1 à 5 : 5 = fidèle et naturelle ; 4 = '
              'correcte avec un défaut mineur ; 3 = compréhensible mais avec une '
              'erreur sensible ; 2 = erreur grave ; 1 = inutilisable.',
          'Indique dans "issues" les défauts parmi : ${judgeIssueKinds.join(', ')} '
              '("aucun" seul si rien à signaler).',
          'Réponds uniquement par un objet JSON {"items":[{"id":…,"score":…,'
              '"issues":[…]}]} avec exactement un élément par item.',
        ].join('\n'),
      ),
      ChatMessage.user(
        jsonEncode({
          'items': [
            for (final i in items)
              {'id': i.id, 'source': i.source, 'translation': i.translation},
          ],
        }),
      ),
    ];

/// Analyse la réponse du juge pour les identifiants [ids]. Les éléments
/// inconnus, sans note valide (hors 1-5) ou en double sont ignorés ; les
/// motifs hors liste sont écartés. Lève `TranslateError` (`invalidResponse`)
/// si aucun JSON exploitable n'existe.
Map<int, JudgeScore> parseJudgeScores(String content, Iterable<int> ids) {
  final json = extractJson(content);
  final items = switch (json) {
    final List<Object?> l => l,
    final Map<Object?, Object?> m when m['items'] is List =>
      m['items']! as List<Object?>,
    _ => null,
  };
  if (items == null) {
    throw const TranslateError(
      TranslateErrorKind.invalidResponse,
      'no judgements array found in the model output',
    );
  }
  final wanted = ids.toSet();
  final out = <int, JudgeScore>{};
  for (final item in items) {
    if (item is! Map) continue;
    final id = item['id'] is int
        ? item['id']! as int
        : int.tryParse('${item['id']}'.trim());
    final score = item['score'] is int
        ? item['score']! as int
        : int.tryParse('${item['score']}'.trim());
    if (id == null ||
        score == null ||
        score < 1 ||
        score > 5 ||
        !wanted.contains(id) ||
        out.containsKey(id)) {
      continue;
    }
    final issues = item['issues'];
    out[id] = JudgeScore(score, [
      if (issues is List)
        for (final x in issues)
          if (x is String && judgeIssueKinds.contains(x)) x,
    ]);
  }
  return out;
}

/// Lots de rétro-traduction : le français est retraduit en japonais avec le
/// prompt de traduction habituel, langues inversées.
List<ChatMessage> buildBackTranslationMessages(
  Batch batch, {
  String gameContext =
      'Monster Hunter Portable 3rd (jeu vidéo PSP de chasse aux monstres)',
}) =>
    buildMessages(
      batch,
      options: PromptOptions(
        sourceLanguage: 'français',
        targetLanguage: 'japonais',
        gameContext: gameContext,
      ),
    );

/// Similarité (0 à 1) entre un texte source et sa rétro-traduction : plus
/// elle est haute, plus le sens a probablement été conservé. Indice bruité
/// sur les phrases courtes.
double roundTripSimilarity(String source, String backTranslated) =>
    similarity(source, backTranslated);
