---
name: session-close
description: Clôture une tâche ou une session : met à jour docs/PROGRESS.md, liste les fichiers modifiés, propose un commit et le prochain prompt.
disable-model-invocation: false
allowed-tools: Read Edit Bash(git status:*) Bash(git diff --stat:*)
---

# Clôture

1. `git status --short` et `git diff --stat`. Vérifier qu'aucun fichier de `local/`, `third_party/`, `*.iso`, `DATA.BIN` ou binaire > 100 Ko n'apparaît. Sinon : alerte.
2. Mettre à jour `docs/PROGRESS.md` :
   - cocher les tâches terminées, avec le niveau atteint : `[compilé]`, `[fixtures]`, `[réel]`, `[en jeu]` ;
   - ajouter les nouvelles sous-tâches découvertes ;
   - « Questions ouvertes » et « À valider par l'humain » avec la commande exacte à lancer.
   - garder PROGRESS.md sous 150 lignes : déplacer l'historique ancien dans `docs/HISTORY.md`.
3. Réponse finale, 15 lignes maximum :

```
FAIT: ...
NIVEAU: compilé / fixtures / réel / en jeu
FICHIERS: liste courte
À LANCER PAR TOI: commande(s)
COMMIT PROPOSÉ: type(scope): message
PROCHAINE ÉTAPE: /clear puis /phase-run [tâche]
```

Ne pas commiter sauf demande explicite.
