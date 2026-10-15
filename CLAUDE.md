# CLAUDE.md — MHP3rd Translation Toolkit

Règles communes à tous les agents (s'appliquent intégralement) :

@AGENTS.md

État d'avancement, à relire au début de chaque session :

@docs/PROGRESS.md

`docs/ARCHITECTURE.md` n'est volontairement pas importé (trop long). Lire uniquement la section utile :
`grep -n "^## " docs/ARCHITECTURE.md` puis lecture de la plage de lignes.

---

## Skills du projet

| Skill | Quand |
|---|---|
| `/phase-run [tâche]` | Point d'entrée de chaque session de travail |
| `/ref-lookup <sujet>` | Avant tout portage de format ou de chiffrement (sous-agent isolé) |
| `/explore-data <question>` | Toute analyse de fichiers réels du jeu (sous-agent isolé) |
| `binary-codec` | Chargé automatiquement dans les paquets cœur |
| `studio-ui` | Chargé automatiquement dans `apps/mh_studio/` |
| `/check [paquet]` | Après chaque modification de code |
| `/session-close` | Fin de chaque tâche |

## Économie de contexte

- Une tâche = une session. Après `/session-close`, l'humain fait `/clear` : l'état est dans PROGRESS.md, pas dans l'historique.
- Ne jamais relire un fichier déjà lu dans la session sauf s'il a changé ; lire par plages de lignes.
- Recherche dans `third_party/` → `/ref-lookup`. Analyse de données → `/explore-data`. Jamais directement dans la conversation principale.
- Vérification → `/check`, jamais `dart test` brut sur tout le dépôt.
- Réponses courtes : pas de récapitulatif du code écrit, pas de recopie de fichiers, diff ou liste de fichiers suffit.

## README

- `README.md` (anglais) est mis à jour après chaque commit si nécessaire (statut des phases, commandes CLI, structure). Le mettre à jour avant de commiter pour qu'il parte dans le même commit.

## Données réelles

- Jamais de binaire réel lu en entier ; `xxd -s <offset> -l <n>` ou script de résumé.
- Une découverte de format confirmée → `docs/FORMATS/<format>.md`.

## Commandes interdites sans accord explicite

- Écrire sur un `.iso` autre qu'une copie dans `out/` ou `local/`.
- `git push`, `git reset --hard`, réécriture d'historique.
- Supprimer dans `local/` ou `third_party/`.
- `dart pub add` : proposer d'abord (licence, justification).

## Style

Réponses en français, techniques, concises. Code, identifiants et commits en anglais ; `docs/` en français.
