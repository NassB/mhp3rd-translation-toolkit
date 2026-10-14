---
name: ref-lookup
description: Cherche dans third_party/ (mhtools, mhef, mhp3-translation-tools) l'implémentation de référence d'un format, du chiffrement ou du patch, et renvoie un résumé précis avec chemins et lignes.
argument-hint: "<sujet, ex. DataCipher, ExtractPluginA, patch header>"
context: fork
agent: Explore
model: sonnet
background: false
allowed-tools: Read Grep Glob
---

# Recherche dans le code de référence

Sujet : $ARGUMENTS

Dépôts disponibles (lecture seule) :
- `third_party/mhtools/` — Java, GPLv3 (`src/dec/`, `src/enc/`, `src/crypt/`, `src/base/`)
- `third_party/mhef/` — Python (`mhef/psp.py`, `mhef/n3ds.py` à ignorer)
- `third_party/mhp3-translation-tools/` — Python (`extractA.py`, `extractC.py`, `patch-iso.py`)

## Méthode

1. Localiser avec Grep/Glob, puis lire seulement les fonctions concernées.
2. Ne pas paraphraser de mémoire : tout ce qui est rapporté doit venir du code lu.

## Format de réponse (≤ 60 lignes)

```
SOURCE: <chemin>:<ligne début>-<ligne fin> (<fonction>)
LICENCE: <licence du dépôt, d'après son fichier LICENSE>
STRUCTURE:
  offset | taille | type | champ | remarque
ALGORITHME:
  étapes numérotées, constantes exactes recopiées
CAS LIMITES:
  ce que le code gère / ne gère pas (ex. offsets ignorés, alias)
DIVERGENCES:
  différences entre dépôts s'il y en a plusieurs
INCONNUES:
  ce que le code ne permet pas de conclure
```

Recopier à l'identique les constantes, tables et clés nécessaires au portage (pas de résumé approximatif des valeurs numériques).
