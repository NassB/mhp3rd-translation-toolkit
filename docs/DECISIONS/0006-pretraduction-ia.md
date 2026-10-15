# 0006 — Pré-traduction par IA (`mh_translate`)

Statut : **proposée le 2026-10-15** (TA1) ; l’API de LM Studio a été mesurée le même jour (§ « Résultats des vérifications »). Les points encore marqués **[À VÉRIFIER]** concernent la qualité et les lots, mesurés en TA2-TA7.

## Contexte

L'utilisateur ne lit pas le japonais. ARCHITECTURE.md §7.6 prévoit une « pré-traduction automatique optionnelle (LLM local ou cloud), toujours en statut `draft`, avec le contexte (fichier, table, chaînes voisines, glossaire) et la contrainte de budget dans la consigne ». Elle n'était pas réalisée. Décision de l'utilisateur (2026-10-15) : la faire avant la phase 4, **fournisseur local LM Studio d'abord**.

État de la machine (constaté en lecture seule le 2026-10-15) : LM Studio installé (`~/.lmstudio`, CLI `lms.exe`) ; modèles de langage `google/gemma-4-26b-a4b-qat` (15,6 Go) et `qwen/qwen3.8-27b` (17,7 Go) ; plongements `text-embedding-nomic-embed-text-v1.5` ; serveur local arrêté, aucun modèle chargé.

## Décision

### 1. Nouveau paquet pur Dart `packages/mh_translate`

- Place dans la chaîne de dépendances : après `mh_tdb` (il lit et écrit la base) et `mh_formats` (linter), avant `mh_build` ; `apps/*` en dépendent, jamais l'inverse. Aucun import Flutter (AGENTS.md §3).
- Contenu prévu : client de chat (TA2), construction du prompt, lots et analyse de la réponse (TA3), moteur de pré-traduction (TA4).
- Le paquet ne connaît ni l'ISO ni le chiffrement : il travaille sur les chaînes de la base.

### 2. Protocole : API « chat completions » compatible OpenAI

- Requête `POST {endpoint}/chat/completions` avec `model`, `messages`, `temperature`, `reasoning_effort: "none"` et un format de sortie `json_schema` ; liste des modèles par `GET {endpoint}/models`. **Vérifié sur LM Studio** (adresse réelle : réglage, 1235 ici ; format des réponses ; sortie JSON contrainte respectée ; raisonnement à désactiver) : voir les résultats plus bas.
- Client écrit avec `dart:io` (`HttpClient`) : **aucune dépendance ajoutée**. Tests contre un `HttpServer` local factice : aucun réseau réel dans les tests unitaires.
- Le fournisseur est une interface (`ChatClient`) : un autre fournisseur (distant) s'ajoutera sans toucher au moteur (TA9).

### 3. Format des échanges

- Les chaînes d'un lot sont envoyées avec un identifiant ; la réponse attendue est un **tableau JSON** `{"id": …, "text": …}`. L'analyse tolère du texte autour du JSON et des chaînes manquantes ou en trop (reprise sur les seules chaînes en défaut). Respecté sur un lot de 5 chaînes synthétiques avec `json_schema` ; **[À VÉRIFIER]** sur des lots plus grands ; repli sur un format ligne à ligne numéroté sinon.
- Consigne système : traduire du japonais vers la langue cible du projet (`project.locale`), **conserver les sauts de ligne**, ne rien ajouter ni retirer d'autre, utiliser les termes du glossaire fournis, rester sous la longueur d'octets indiquée par chaîne.
- Les marqueurs mhtools (`<NEWLINE>`, `<EMPTY STRING>`) ne sont **jamais** envoyés : le modèle reçoit le texte réel (UTF-8, `\n`), comme la base le stocke.

### 4. Contrôles et statut

- Résultat toujours enregistré en `draft`, via `TranslationRepository.saveTranslation` (concurrence optimiste, historique écrit). Une traduction `translated`, `reviewed` ou `locked` n'est écrasée qu'avec une option explicite ; les alias sont ignorés.
- Chaque résultat est contrôlé par `lintTranslation` (nombre de sauts de ligne, NUL, termes obligatoires) et par le budget d'octets de la chaîne. Un seul nouvel essai avec un message correctif ; au-delà, la chaîne est signalée en échec et laissée intacte.
- Le build « nightly » ne prend que `translated` : aucune traduction automatique n'entre dans l'ISO sans relecture et changement de statut par l'humain.

### 5. Confidentialité (AGENTS.md §4.2, ARCHITECTURE.md §13)

- Endpoint **local par défaut** (`localhost`, `127.0.0.1`, `[::1]`). Tout autre endpoint exige une confirmation explicite (`--allow-remote` en CLI, avertissement et confirmation dans le studio) : envoyer du texte du jeu à un tiers est irréversible.
- Le texte du jeu n'apparaît **ni dans les journaux, ni dans les rapports, ni dans les messages d'erreur** ; le client ne journalise pas les corps de requête ni de réponse.
- Une clé d'API éventuelle (fournisseur distant, TA9) se lit dans une variable d'environnement ; elle n'est jamais écrite dans `project.json`, la base, un fichier de réglages ou le dépôt.
- Les tests et fixtures sont synthétiques (aucun texte du jeu dans le dépôt).

### 6. Évaluation (TA7)

L'utilisateur ne peut pas juger le japonais : la qualité est évaluée par taux de chaînes sans constat du linter, respect du budget, cohérence du glossaire et **rétro-traduction** sur un échantillon, pour au moins Gemma 4 26B-A4B et Qwen 3.8 27B. Aucun modèle n'est déclaré « bon » avant cette mesure.

## Vérifications à faire avant TA2

Sur la machine de l'utilisateur, serveur LM Studio démarré et un modèle chargé :

1. `lms server status` : port réel du serveur.
2. `GET /v1/models` : identifiants exacts des modèles exposés.
3. `POST /v1/chat/completions` avec **une chaîne synthétique** (jamais du texte du jeu) : champs de la réponse (`choices[0].message.content`, `usage`), comportement avec un format de sortie JSON demandé, durée.
4. Capacité de contexte du modèle chargé (taille des lots).

Résultats consignés ci-dessous au fur et à mesure.

## Résultats des vérifications (2026-10-15, LM Studio, `google/gemma-4-26b-a4b-qat`)

Toutes les requêtes ci-dessous n'ont contenu que des **phrases japonaises synthétiques** (« bonjour », « merci »…), jamais de texte du jeu.

| Point | Constat |
|---|---|
| Adresse | **Port 1235 sur cette machine** (pas 1234 : 1234 ne répond pas). L'adresse est donc un **réglage**, jamais une constante ; LM Studio affiche l'adresse réelle. |
| `GET /v1/models` | Liste **tous** les modèles installés (Gemma, Qwen, plongements), chargés ou non : elle ne dit pas lesquels sont chargés. |
| `GET /api/v0/models[/id]` (spécifique LM Studio) | Donne `state` (`loaded` / `not-loaded`), `max_context_length` (262 144) et `loaded_context_length` (**16 384** pour Gemma chargé). Optionnel : le client ne doit pas en dépendre. |
| Chargement | Un modèle `not-loaded` est chargé **à la première requête** (≈ 29 s) ; les requêtes suivantes n'ont pas ce coût. |
| Réponse `POST /v1/chat/completions` | Format OpenAI : `choices[0].message.content`, `finish_reason` (`stop` / `length`), `usage` (`prompt_tokens`, `completion_tokens`, `completion_tokens_details.reasoning_tokens`). |
| **Modèle « raisonnant »** | Gemma 4 produit une chaîne de raisonnement dans `message.reasoning_content`, **qui compte dans `max_tokens`**. Avec `max_tokens: 200`, `content` est **vide** et `finish_reason: "length"` (197 jetons de raisonnement). Avec 2 000, `content` est correct (328 jetons dont 309 de raisonnement). |
| **`reasoning_effort: "none"`** | **Fonctionne** : 0 jeton de raisonnement, **≈ 3 s** au lieu de 38 s pour un lot de 5 chaînes, `reasoning_content` vide. Le paramètre `chat_template_kwargs.enable_thinking: false` est **sans effet** (1 447 jetons de raisonnement). |
| Sortie structurée | `response_format` de type `json_schema` (`strict: true`) **est respecté** : `content` est un JSON valide `{"items":[{"id":…,"text":…}]}`, les `\n` sont conservés. |
| Retour à la ligne | Cas `ありがとう\nございます。` → `Merci\nbeaucoup.` (le saut de ligne est conservé). |

### Conséquences sur la décision

1. **Toujours envoyer `reasoning_effort: "none"`** (avec repli si le fournisseur le refuse), lire **uniquement `message.content`**, et prévoir un `max_tokens` large. Sinon : réponses vides ou 10 fois plus lentes.
2. **Ne jamais lire ni journaliser `reasoning_content`** : il recopie le texte source et le raisonnement (même règle de confidentialité que les corps de requête).
3. **Utiliser la sortie structurée `json_schema`** pour les lots ; garder l'analyse tolérante de TA3 comme filet (autres fournisseurs).
4. **Taille des lots** : contexte chargé **16 384 jetons** ; viser des lots dont `prompt_tokens + sortie` restent largement en dessous (ordre de grandeur 30 à 50 chaînes, à calibrer avec `usage.prompt_tokens`, jamais avec une estimation seule).
5. **L'endpoint, le modèle et un indicateur « modèle raisonnant »** sont des réglages ; `GET /v1/models` ne garantit pas que le modèle est chargé : prévoir le délai de premier chargement dans les délais d'attente (≥ 120 s pour la première requête).

### Non vérifié (reste à mesurer, TA2-TA7)

- Qualité de traduction sur du texte de jeu (aucune mesure) ; Qwen 3.8 27B (non testé) ;
- comportement sur des lots de 30 à 50 chaînes, chaînes longues ou avec beaucoup de sauts de ligne ;
- débit réel sur un fichier complet (101 à 9 140 chaînes) ;
- respect de la consigne « rester sous N octets » (à tester avec des contraintes réelles).

## Alternatives rejetées

- **Intégrer le SDK d'un fournisseur** : dépendance lourde, couplage à un fournisseur, contraire à « local d'abord ».
- **Traduction par la conversation avec l'assistant** : ferait transiter beaucoup de texte du jeu par les journaux de session (AGENTS.md §4.2), lente et non reproductible.
- **Dépendance HTTP (`package:http`, `dio`)** : inutile pour deux requêtes JSON ; `dart:io` suffit.
- **Écrire directement en `translated`** : contourne la relecture humaine, interdit par le principe « toujours en `draft` » (ARCHITECTURE.md §7.6).
- **Mettre la pré-traduction dans `mh_build` ou `mh_tdb`** : mélange réseau et pipeline ; un paquet dédié garde `mh_tdb` sans accès réseau.
