# 0005 — Flutter (FVM) et dépendances de `mh_studio`

## Contexte
Phase 3 : application Flutter desktop (`apps/mh_studio`). Dépendances validées par l'humain le 2026-10-15.

## Décision
- SDK : Flutter stable **3.47.6** (Dart **3.13.5**) installé par `fvm` 4.3.1 (cache `~/fvm/versions/stable`), épinglé par `.fvmrc` (`"flutter": "stable"`). Le workspace entier se résout désormais avec ce Dart ; `scripts/check.sh` du dépôt entier reste `OK`.
- `apps/mh_studio` créé avec `flutter create` (plateformes windows, linux, macos), intégré au workspace (`resolution: workspace`). `cupertino_icons` et `flutter_lints` retirés (non approuvé / `lints ^6` en conflit avec `lints ^5` du workspace) ; les règles viennent de l'`analysis_options.yaml` racine.
- Dépendances ajoutées : `flutter_riverpod` 3.4.3 (MIT), `go_router` 18.1.0 (BSD-3-Clause) — licences lues sur pub.dev.
- Non ajoutés : `sqlite3_flutter_libs` (EOL), `drift_flutter` (inutile : `mh_tdb` ouvre SQLite via `sqlite3`), `file_picker` (T33).
- Générateur Riverpod (option B choisie par l humain, 2026-10-15) : `riverpod_annotation` 4.0.2 et `riverpod_generator` 4.0.3 (MIT), `build_runner` ^2.15.1 en dev ; la résolution fait descendre `analyzer` 10.2 → 9.0, `flutter_riverpod` 3.4.3 → 3.3.1 (contrainte `^3.3.1`) et ajoute en transitif `mockito`, `code_builder`, `freezed_annotation`, `analyzer_buffer`, `riverpod_analyzer_utils`. `build_runner` avertit que le langage SDK 3.13 est plus récent que celui d `analyzer` 9.0 (3.11) : surveiller si une syntaxe récente est un jour mal générée. Le `.g.dart` est commité.

## Environnement
- `scripts/setup_studio.ps1` échoue sous Windows PowerShell 5.1 (`fvm` écrit un avertissement sur stderr, converti en erreur par `$ErrorActionPreference = 'Stop'`) et `pwsh` est absent : les étapes 2-3 ont été faites à la main. `.fvm/flutter_sdk` (lien symbolique) n'existe pas sous Windows ici : mettre `~/fvm/versions/stable/bin` dans le PATH.
- **Visual Studio (charge « Desktop development with C++ ») n'est pas installé** : `flutter run -d windows` / `flutter build windows` sont impossibles tant que l'humain ne l'installe pas. `flutter test` et `flutter analyze` fonctionnent.

## Alternatives
Voir 0004 pour le même raisonnement sur SQLite. Providers Riverpod écrits à la main (sans générateur) si le générateur est refusé.
