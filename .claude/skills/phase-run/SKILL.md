---
name: phase-run
description: Exécute la prochaine tâche de la phase en cours de docs/PROGRESS.md, de bout en bout (plan, code, tests, mise à jour du suivi).
argument-hint: "[tâche optionnelle]"
disable-model-invocation: true
---

# Exécuter une tâche de phase

Tâche demandée : $ARGUMENTS (si vide : première tâche non cochée de `docs/PROGRESS.md`).

## Étapes

1. Lire `docs/PROGRESS.md`. Identifier la phase, la tâche, les questions ouvertes bloquantes.
   - Si une question ouverte bloque la tâche : s'arrêter et la poser. Ne rien coder.
2. Lire **uniquement** la section utile de `docs/ARCHITECTURE.md` (repérer le titre avec `grep -n "^## " docs/ARCHITECTURE.md`, puis lire la plage de lignes). Ne pas lire le fichier entier.
3. Si la tâche implique un format binaire ou le chiffrement : invoquer `/ref-lookup` pour obtenir la référence exacte depuis `third_party/`, puis suivre le skill `binary-codec`.
4. Présenter un plan de 5 à 10 lignes maximum : fichiers créés/modifiés, tests prévus, critère de réussite. Attendre la validation si la tâche touche plus de 3 fichiers ou une règle de AGENTS.md §4.
5. Implémenter par petits incréments. Après chaque incrément : `/check <paquet>`.
6. Si un test `integration` est nécessaire et que `MHP3_ISO` n'est pas défini : l'écrire, le laisser en `skip`, l'ajouter à « À valider par l'humain » dans PROGRESS.md.
7. Terminer avec `/session-close`.

## Garde-fous

- Une seule tâche par invocation. Si la tâche est trop grosse, la découper dans PROGRESS.md et ne faire que la première sous-tâche.
- Ne jamais passer à la phase suivante sans que le critère de sortie de la phase soit validé par l'humain (case cochée dans PROGRESS.md).
- Si une même erreur revient après 2 tentatives de correction : s'arrêter, résumer le diagnostic, demander.
