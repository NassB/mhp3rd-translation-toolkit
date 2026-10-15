// Construction du prompt de pré-traduction (docs/DECISIONS/0006).
//
// Le texte envoyé est le texte réel (UTF-8, `\n`), jamais les marqueurs
// mhtools. Aucune journalisation : les messages ne sont que retournés.

import 'dart:convert';

import 'package:mh_formats/mh_formats.dart';

import 'batching.dart';
import 'chat_client.dart';

/// Réglages du prompt.
final class PromptOptions {
  /// Voir les champs.
  const PromptOptions({
    this.sourceLanguage = 'japonais',
    this.targetLanguage = 'français',
    this.gameContext =
        'Monster Hunter Portable 3rd (jeu vidéo PSP de chasse aux monstres)',
    this.extraRules = const [],
  });

  /// Langue des textes à traduire (« japonais » ; « français » pour la
  /// rétro-traduction d'une évaluation).
  final String sourceLanguage;

  /// Langue cible, en toutes lettres (« français », « anglais »…).
  final String targetLanguage;

  /// Description du jeu donnée au modèle.
  final String gameContext;

  /// Règles supplémentaires (style, tutoiement…), une par entrée.
  final List<String> extraRules;
}

/// Contexte d'un lot : chaînes voisines et indications de correction.
final class BatchContext {
  /// Voir les champs.
  const BatchContext({
    this.before = const [],
    this.after = const [],
    this.glossary = const [],
    this.corrections = const {},
  });

  /// Sources qui précèdent le lot, **pour comprendre seulement** (à ne pas
  /// traduire).
  final List<String> before;

  /// Sources qui suivent le lot, idem.
  final List<String> after;

  /// Glossaire du projet ; seuls les termes présents dans le lot sont envoyés.
  final List<GlossaryEntry> glossary;

  /// Indication de correction par identifiant de chaîne (second essai :
  /// « 2 sauts de ligne attendus », « terme obligatoire absent : X »…).
  final Map<int, String> corrections;
}

/// Schéma JSON de la réponse : `{"items":[{"id":n,"text":"…"}]}`.
JsonSchemaFormat translationSchema() => const JsonSchemaFormat(
      name: 'translations',
      schema: {
        'type': 'object',
        'properties': {
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'integer'},
                'text': {'type': 'string'},
              },
              'required': ['id', 'text'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['items'],
        'additionalProperties': false,
      },
    );

/// Consigne système.
String systemPrompt(PromptOptions o) {
  final rules = [
    'Tu traduis des textes du ${o.sourceLanguage} vers le ${o.targetLanguage} pour le '
        'jeu ${o.gameContext}.',
    'Tu reçois un objet JSON avec une liste "items" (chacun : "id", "text", '
        '"max_bytes", éventuellement "fix"). Tu réponds uniquement par un objet '
        'JSON {"items":[{"id":…,"text":"…"}]} avec exactement un élément par '
        'item reçu, le même "id", et la traduction dans "text".',
    'Conserve exactement les sauts de ligne du texte source (même nombre de '
        '"\\n") ; n\'en ajoute et n\'en retire aucun. N\'ajoute aucun marqueur '
        'ni commentaire, et ne traduis pas les listes "context_before" et '
        '"context_after" : elles ne servent qu\'à comprendre la situation.',
    '"max_bytes" est la longueur maximale de la traduction en octets UTF-8 '
        '(les lettres accentuées comptent pour 2) : ne la dépasse jamais. Le '
        'fichier du jeu a un budget d\'octets total : vise une longueur '
        'comparable à celle du texte source en octets UTF-8 et sois concis.',
    'Si "glossary" est présent, emploie la traduction indiquée pour chaque '
        'terme ; les termes marqués "mandatory" sont obligatoires.',
    'Si un item a un champ "fix", c\'est la correction attendue d\'un essai '
        'précédent : applique-la.',
    ...o.extraRules,
  ];
  return rules.join('\n');
}

/// Messages à envoyer pour [batch] : consigne système + contenu JSON.
List<ChatMessage> buildMessages(
  Batch batch, {
  PromptOptions options = const PromptOptions(),
  BatchContext context = const BatchContext(),
}) {
  final matched = matchGlossary(
    batch.units.map((u) => u.source).join('\n'),
    context.glossary,
  )..sort((a, b) => (b.mandatory ? 1 : 0) - (a.mandatory ? 1 : 0));
  final payload = <String, Object?>{
    if (context.before.isNotEmpty) 'context_before': context.before,
    if (matched.isNotEmpty)
      'glossary': [
        for (final g in matched)
          {
            'source': g.sourceTerm,
            'target': g.targetTerm,
            if (g.mandatory) 'mandatory': true,
          },
      ],
    'items': [
      for (final u in batch.units)
        {
          'id': u.id,
          'text': u.source,
          'max_bytes': u.maxBytes,
          if (context.corrections[u.id] != null)
            'fix': context.corrections[u.id],
        },
    ],
    if (context.after.isNotEmpty) 'context_after': context.after,
  };
  return [
    ChatMessage.system(systemPrompt(options)),
    ChatMessage.user(jsonEncode(payload)),
  ];
}

/// Nom français de la langue de [locale] (`fr` → « français ») pour la
/// consigne ; un code inconnu est repris tel quel.
String languageNameOf(String locale) =>
    const {
      'fr': 'français',
      'en': 'anglais',
      'es': 'espagnol',
      'de': 'allemand',
      'it': 'italien',
      'pt': 'portugais',
    }[locale] ??
    locale;
