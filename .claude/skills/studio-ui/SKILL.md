---
name: studio-ui
description: Conventions pour l'application Flutter desktop mh_studio (Riverpod, éditeur de traduction, jauges de budget, aperçu police).
paths: apps/mh_studio/**
---

# mh_studio (Flutter desktop)

## Architecture

- `lib/features/<feature>/` : `data/` (adaptateurs vers `mh_tdb`), `application/` (providers Riverpod générés), `presentation/` (widgets).
- Aucune logique métier dans les widgets ; le calcul de budget vient de `mh_budget`, jamais réimplémenté côté UI.
- État asynchrone en `AsyncValue`, providers `@riverpod` générés, `ref.watch` dans `build`, `ref.read` dans les callbacks.
- Navigation `go_router`. Thème Material 3, mode sombre par défaut.

## Écrans (ordre de priorité)

1. Liste des fichiers : ID, libellé, progression, jauge `rebuilt/strict/slot`.
2. Éditeur : source | cible | glossaire ; tokens de contrôle non éditables (chips) ; jauge octets du fichier en direct ; alerte px/lignes du profil.
3. Aperçu : rendu avec les métriques de la police extraite (quand phase 4 disponible).
4. Build : lancement du pipeline `mh_build`, affichage du rapport.

## Performances

- Listes virtualisées (`ListView.builder`), pagination côté repository au-delà de 500 entrées.
- Debounce 150 ms sur la mesure de budget pendant la saisie.

## Tests

- Tests de widgets pour l'éditeur (tokens protégés, jauge qui passe au rouge).
- Pas de golden tests contenant du texte du jeu.
