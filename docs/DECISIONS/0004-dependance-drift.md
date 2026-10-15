# 0004 — Dépendances drift / sqlite3 / drift_dev / build_runner (`mh_tdb`)

## Contexte
ARCHITECTURE.md §7.1 prévoit SQLite via `drift` pour la base de traduction locale (T19, phase 2).

## Décision
Ajout à `packages/mh_tdb` (validé par l'humain le 2026-10-15) :

| Paquet | Version | Licence (LICENSE du cache pub vérifiée) |
|---|---|---|
| `drift` | 2.31.0 | MIT |
| `sqlite3` | 2.9.4 | MIT |
| `drift_dev` (dev) | 2.31.0 | MIT |
| `build_runner` (dev) | 2.15.1 | BSD-3-Clause |

- `sqlite3` 2.x charge la bibliothèque SQLite du système : `winsqlite3.dll` sous Windows (présente dans System32), `libsqlite3` sous Linux/macOS. Les tests la sélectionnent explicitement.
- L'ajout a rétrogradé `analyzer` 12.1.0 → 10.2.0 pour tout le workspace ; `scripts/check.sh` sur le dépôt entier reste `OK`.
- `mh_studio` ajoutera ses propres paquets Flutter de SQLite à la phase 3.

## Alternatives
`sqlite3` seul ou `sqflite_common_ffi` (SQL manuel, sans typage) ; `isar`/`floor` (hors architecture).
