# QA de la pré-traduction par IA (TA7)

Statut : **mesures faites le 2026-10-15, relecture humaine à faire** (voir §5). Ce document ne contient aucun texte du jeu.

## 1. Objectif

Choisir le modèle par défaut de la pré-traduction (`mh_translate`) sans que l'utilisateur lise le japonais. Les mesures ci-dessous servent à **comparer des modèles entre eux** et à repérer les cas à relire ; elles ne prouvent pas qu'une traduction est bonne.

## 2. Protocole

Script : `packages/mh_translate/tool/eval_models.dart` (outil local, non livré). Il est rejouable avec n'importe quelle paire de modèles :

1. Deux projets jetables sont créés avec `mhtk init` puis `mhtk extract` (`out/ta7_a`, `out/ta7_b`).
2. Chaque modèle traduit les **mêmes 50 chaînes** (les 50 premières à traduire de #2819), avec le moteur réel (`preTranslateFile` : glossaire, voisins, contrôle du linter, enveloppe d'octets du fichier, un seul nouvel essai).
3. Chaque production est ensuite **notée et rétro-traduite par l'autre modèle** (indépendance du juge) :
   - **juge** : note entière 1 à 5 (fidélité et naturel) et défauts dans une liste fermée (`omission`, `addition`, `contresens`, `terme_non_traduit`, `registre`, `fluidite`, `aucun`) ; sortie JSON contrainte, température 0 ;
   - **rétro-traduction** : le français est retraduit en japonais, puis comparé à la source par **similarité de trigrammes** (même mesure que la mémoire de traduction).
4. Le script affiche des **agrégats seulement**. Le détail (japonais, traductions, notes, rétro-traductions) est écrit dans `out/eval/ta7_report.md` : fichier local, **ignoré par git, à ne jamais commiter ni publier**.

Matériel : LM Studio local, port 1235, `reasoning_effort: "none"`, contexte chargé 16 384, température de traduction 0,2 (non évaluée).

## 3. Résultats (50 chaînes de #2819, 2026-10-15)

| Mesure | Gemma 4 26B-A4B (`google/gemma-4-26b-a4b-qat`) | Qwen 3.8 27B (`qwen/qwen3.8-27b`) |
|---|---|---|
| Chaînes enregistrées / refusées | 50 / 0 | 50 / 0 |
| Chaînes raccourcies (enveloppe d'octets) | 5 | 6 |
| Fichier dans son budget d'octets | oui (−13 o) | oui (−11 o) |
| Temps total | **37 s** (0,75 s/chaîne) | **377 s** (7,55 s/chaîne) |
| Jetons (prompt / sortie) | 4 013 / 1 399 | 3 901 / 2 287 |
| Rapport octets traduction/source | 1,04 (méd. 1,06) | 1,06 (méd. 1,05) |
| Note du juge (par l'autre modèle) | moyenne **4,46** ; ≥ 4 : 90 % ; ≤ 2 : 2 % | moyenne **4,46** ; ≥ 4 : 92 % ; ≤ 2 : 8 % |
| Défauts relevés par le juge | registre 13, fluidité 5, omission 3, contresens 1, terme non traduit 1 (29 sans défaut) | fluidité 13, contresens 5, registre 1 (31 sans défaut) |
| Similarité rétro-traduction | moyenne 0,27 ; médiane 0,15 ; < 0,15 : 48 % | moyenne 0,35 ; médiane 0,26 ; < 0,15 : 42 % |

Projection de durée (0,75 contre 7,55 s/chaîne, sur les 15 051 chaînes extraites) : environ **3 h** avec Gemma, environ **31 h** avec Qwen.

## 4. Lecture honnête des chiffres

- **Vitesse et respect des contraintes** : comparaison fiable. Les deux modèles respectent les sauts de ligne, le glossaire et le budget d'octets (0 refus), Gemma est **10 fois plus rapide**.
- **Qualité** : les deux modèles obtiennent la **même note moyenne (4,46)**, mais **chacun est jugé par l'autre**, et les deux juges n'ont pas la même sévérité ni les mêmes réflexes : Qwen (juge de Gemma) relève surtout le registre, Gemma (juge de Qwen) relève surtout la fluidité et plus de contresens (5 contre 1). On ne peut donc **pas** conclure qu'un modèle traduit mieux que l'autre.
- **Rétro-traduction** : la similarité plus haute de Qwen est **confondue** avec la qualité du modèle qui a rétro-traduit (un modèle différent pour chaque série). Elle est surtout utile pour repérer les chaînes à faible score (traduction possiblement infidèle), pas pour classer les modèles. Sur des phrases courtes japonaises, 3 trigrammes ne disent presque rien.
- L'échantillon est petit (50 chaînes d'un seul fichier) : de petites différences ne sont pas significatives.

## 5. Ce qui reste à faire par l'humain

Ouvrir `out/eval/ta7_report.md` et lire **une vingtaine de lignes** en regardant uniquement le français :

1. Les deux traductions (A et B) sont-elles du français naturel ? Laquelle préfères-tu sur les mêmes chaînes ?
2. Les chaînes à note ≤ 2 ou à rétro-traduction très éloignée sont-elles vraiment mauvaises ? (outil externe de traduction possible pour vérifier le sens sans parler japonais)
3. Le ton (tutoiement/vouvoiement, style « jeu de rôle ») convient-il ? À corriger par une règle supplémentaire dans les options du prompt (`extraRules`).

Résultat attendu : « A », « B » ou « équivalent », avec les défauts récurrents éventuels.

## 6. Décision provisoire

- **Modèle par défaut : Gemma 4 26B-A4B** (`google/gemma-4-26b-a4b-qat`) : même note moyenne que Qwen, 10 fois plus rapide, aucun refus. À confirmer par la relecture du §5.
- **Qwen 3.8 27B** reste utilisable (même mécanisme, choisir le modèle dans le dialogue) pour une seconde opinion sur des chaînes difficiles.
- **Température** : 0,2 conservée, **non évaluée** (à tester si la relecture montre de la variabilité).
- Rien n'est « validé » : toute traduction automatique reste en `draft` et passe par la relecture humaine avant de devenir `translated`.

## 7. Rejouer l'évaluation

```bash
dart run packages/mh_translate/tool/eval_models.dart http://127.0.0.1:1235/v1 \
  google/gemma-4-26b-a4b-qat qwen/qwen3.8-27b out/ta7_a out/ta7_b 2819 50 out/eval/ta7_report.md
```

Prérequis : deux projets créés comme au §2, serveur LM Studio démarré, ≥ 32 Go de RAM (les deux modèles ne tiennent pas ensemble en mémoire : LM Studio décharge l'un pour charger l'autre). Durée observée : environ 10 minutes.
