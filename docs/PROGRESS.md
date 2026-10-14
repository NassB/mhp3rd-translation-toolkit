# PROGRESS.md

## Phase en cours

Phase 0 — Fondations (`mh_binary`, `mh_iso`, chiffrement `mh_databin`)

Critère de sortie : `encrypt(decrypt(x, lba), lba) == x` sur 100 % de `DATA.BIN` (test `integration`).

## Tâches (une ligne = une session, ≤ ~300 lignes de code)

Niveaux : `[compilé]`, `[fixtures]`, `[réel]`, `[en jeu]`.

- [x] **T0 Squelette monorepo** [compilé] — `git init`, `dart pub get` et `scripts/check.sh` (`OK`) passés ; `git check-ignore -v` ignore `local/`, `third_party/`, `x.iso`. Reste : premier commit (humain).
- [x] **T1 Licences** [compilé] — `docs/DECISIONS/0001-licences.md` écrit (3 dépôts GPLv3+, licence globale proposée GPLv3+, à confirmer par l'humain).
- [ ] **T2 `mh_binary` : ByteReader** — LE u8/u16/u32/i32, `bytes(n)`, `seek`, `skip`, bornes → `FormatError` avec offset. Critère : tests de lecture + hors bornes sur fixtures.
- [ ] **T3 `mh_binary` : ByteWriter + alignement + erreurs** — `ByteWriter` LE, `alignUp`, hiérarchie `MhError` (`FormatError`, `CryptoError`, `PatchError`, `IsoError`). Critère : écriture puis relecture identique ; `alignUp(n, 2048)` testé.
- [ ] **T4 `mh_iso` : parseur ISO 9660** — descripteur primaire (secteur 16), parcours des répertoires, `locate('PSP_GAME/USRDIR/DATA.BIN')`. Critère : ISO synthétique minimale générée par builder de test, offset retrouvé.
- [ ] **T5 `mh_iso` : registre + MD5 + cloneTo** — lecture de `config/game_versions.yaml`, vérification MD5 et égalité offset calculé/registre, `cloneTo` (jamais d'écriture sur la source). Critère : tests fixtures ; test `integration` sur `MHP3_ISO` à lancer par l'humain.
- [ ] **T6 `mh_databin` : `DataCipher`** — portage de `third_party/mhef/mhef/psp.py` (via `/ref-lookup`, licence notée en T1). Critère : `encrypt(decrypt(x, lba), lba) == x` sur fixtures aléatoires + vecteur de référence.
- [ ] **T7 `mh_databin` : TOC et index** — lecture de la TOC, `IndexEntry(id, lba, slotBytes, sha1Plain)`. Critère : index d'un `DATA.BIN` synthétique chiffré avec le codec de T6.
- [ ] **T8 Test `integration` de round-trip** — `MHP3_ISO` absent ⇒ skip. Critère de sortie de la phase : `scripts/check.sh packages/mh_databin --integration` = OK (humain).
- [ ] **T9 `mhtk index`** — commande CLI affichant nombre de fichiers, plus gros slot, somme des tailles. Critère : exécution sur fixture.

## Fait

- Squelette T0 vérifié [compilé] : Dart 3.9.0, `dart pub get` OK, `scripts/check.sh` = OK. Flutter/FVM absents (studio non créé).

## Questions ouvertes

- Valider la licence globale GPLv3+ (voir 0001-licences.md) avant T6. `MHP3_ISO` et `local/MHP3.iso` encore absents.
- `apps/mh_studio` : créé par `pwsh scripts/setup_studio.ps1` (FVM). Les deps Flutter (Riverpod, etc.) seront proposées avant ajout. `apps/mh_patcher` et `server/mh_server` restent à créer à leur phase.
- `scripts/check.sh` appelle `dart`/`flutter` : les lancer avec `.fvm/flutter_sdk/bin` dans le PATH (le Dart de FVM sert pour tout le workspace).
- `lints: ^5.0.0` et `test: ^1.25.0` supposent Dart ≥ 3.6 ; à confirmer avec `dart --version`.

## Décisions

Voir `docs/DECISIONS/`.

## À valider par l'humain sur données réelles

- Après T4/T5 : `MHP3_ISO=local/MHP3.iso scripts/check.sh packages/mh_iso --integration`
- Fin de phase 0 : `scripts/check.sh packages/mh_databin --integration`
