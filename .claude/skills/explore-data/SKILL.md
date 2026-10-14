---
name: explore-data
description: Analyse des fichiers réels du jeu (DATA.BIN déchiffré, fichiers extraits) dans un contexte isolé et renvoie un résumé compact, sans jamais charger de binaire ou de texte du jeu dans la conversation principale.
argument-hint: "<question, ex. 'quels fichiers ressemblent à des tables de texte ?'>"
context: fork
model: sonnet
background: false
allowed-tools: Read Grep Glob Bash(xxd:*) Bash(dart run tools/explore/*) Bash(ls:*) Bash(wc:*) Bash(head:*)
---

# Exploration des données réelles

Question : $ARGUMENTS

## Règles

- Données dans `local/` uniquement (non versionné). Si absent : répondre « données absentes » et s'arrêter.
- Jamais `cat` ni lecture complète d'un binaire. Utiliser `xxd -s <offset> -l <≤256>`.
- Pour toute analyse sur plusieurs fichiers : écrire un script Dart dans `tools/explore/<nom>.dart` qui imprime un **résumé** (compteurs, tailles, offsets, histogrammes), puis l'exécuter. Réutiliser les paquets du dépôt (`mh_binary`, `mh_databin`, `mh_formats`) quand ils existent.
- Ne jamais afficher plus de 5 chaînes de texte du jeu, tronquées à 40 caractères.
- Écrire les sorties détaillées dans `local/explore/<nom>.txt`, pas dans la réponse.

## Format de réponse (≤ 40 lignes)

```
QUESTION: ...
MÉTHODE: script(s) utilisé(s), commande exacte pour rejouer
RÉSULTATS: faits observés, chiffrés
HYPOTHÈSES: ce qui est probable mais non prouvé, avec niveau de confiance
À DOCUMENTER: ce qui mérite une entrée dans docs/FORMATS/
DÉTAILS: chemin du fichier local/explore/... contenant la sortie complète
```
