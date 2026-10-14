# PROGRESS.md

## Phase en cours

Phase 0 — Fondations (`mh_binary`, `mh_iso`, chiffrement `mh_databin`)

Critère de sortie : `encrypt(decrypt(x, lba), lba) == x` sur 100 % de `DATA.BIN` (test `integration`).

## Tâches (une ligne = une session, ≤ ~300 lignes de code)

Niveaux : `[compilé]`, `[fixtures]`, `[réel]`, `[en jeu]`.

- [x] **T0 Squelette monorepo** [compilé] — `git init`, `dart pub get` et `scripts/check.sh` (`OK`) passés ; `git check-ignore -v` ignore `local/`, `third_party/`, `x.iso`. Reste : premier commit (humain).
- [x] **T1 Licences** [compilé] — `docs/DECISIONS/0001-licences.md` écrit (3 dépôts GPLv3+, licence globale proposée GPLv3+, à confirmer par l'humain).
- [x] **T2 `mh_binary` : ByteReader** [fixtures] — LE u8/u16/u32/i32, `bytes(n)` (vue sans copie), `seek`, `skip`, bornes → `FormatError` avec offset. `scripts/check.sh packages/mh_binary` = OK. `MhError` + `FormatError` créés ici (minimaux) ; T3 ajoute `CryptoError`, `PatchError`, `IsoError`.
- [x] **T3 `mh_binary` : ByteWriter + alignement + erreurs** [fixtures] — `ByteWriter` LE (u8/u16/u32/i32/bytes/fill/padTo, plages vérifiées), `alignUp` + `sectorSize`, `CryptoError`/`PatchError`/`IsoError`. `scripts/check.sh packages/mh_binary` = OK. Reste : commit (humain). `BudgetError` viendra avec `mh_budget`.
- [x] **T4 `mh_iso` : parseur ISO 9660** [fixtures] — `Iso9660` (PVD secteur 16, `list`, `locate` insensible à la casse, suffixe `;1` retiré, bornes → `IsoError`), `IsoEntry`, builder `test/support/iso_builder.dart`. `scripts/check.sh packages/mh_iso` = OK. Lecture via `IsoReadAt` (prêt pour fichier sans tout charger en mémoire). Reste : commit (humain).
- [x] **T5 `mh_iso` : registre + MD5 + cloneTo** [fixtures] — `GameVersionRegistry` (YAML, deps `crypto` + `yaml` ajoutées), `IsoImage`/`FileIsoImage.open` (MD5 en flux, version inconnue ou offset DATA.BIN divergent → `IsoError`), `openRead`, `cloneTo` (refuse tout fichier existant, source comprise). `scripts/check.sh packages/mh_iso` = OK. Test `integration` écrit, `skip` sans `MHP3_ISO`. Reste : commit (humain).
- [x] **T6 `mh_databin` : `DataCipher`** [fixtures] — portage de `mhef/psp.py` (`encrypt`/`decrypt`, tables, flux de clés) dans `lib/src/data_cipher.dart` (en-tête GPLv3+). Round-trip sur blocs aléatoires, lba 0 = graine par défaut, erreurs typées (longueur non multiple de 4, LBA hors u32). Aucun vecteur de référence dans `third_party/` : vecteur de non-régression (clé 0xAE1DED19 recalculée à la main). `scripts/check.sh packages/mh_databin` = OK. Reste : commit (humain). Exceptions non chiffrées (indices 17-20, 81-92) traitées en T7.
- [x] **T7 `mh_databin` : TOC et index** [fixtures] — `DataBinToc.parse` (TOC chiffrée LBA 0, sentinelle = taille/2048, erreurs typées), `DataBinEntry` (id base 1, lba, slotBytes, sha1Plain, encrypted, `modId`), `DataBinIndex.build` (exceptions en clair 17-20/81-92 = constante `mhp3JpPlainIndices`, psp.py l.109 ; pas de champ dans le YAML). Dép. `crypto` ajoutée à `mh_databin`. `sizeBytes`/`kind`/`label` reportés (catalogue). `scripts/check.sh packages/mh_databin` = OK. Reste : commit (humain).
- [x] **T8 Test `integration` de round-trip** [compilé] — `packages/mh_databin/test/data_bin_roundtrip_integration_test.dart` (tags `integration`, `slow`) : ouvre l'ISO via `FileIsoImage`, construit l'index, vérifie `encrypt(decrypt(slot, lba), lba) == slot` pour chaque fichier chiffré. `skip` sans `MHP3_ISO` ; `scripts/check.sh packages/mh_databin` = OK. Non exécuté sur données réelles : critère de sortie phase 0 à valider par l'humain (`scripts/check.sh packages/mh_databin --integration`).
- [x] **T9 `mhtk index`** [fixtures] — `runIndex` (`apps/mh_cli/lib/src/index_command.dart`) : `mhtk index <DATA.BIN>` ou `--iso <iso> [--config ...]` ; affiche fichiers, plus gros slot, somme des slots. Test sur DATA.BIN synthétique + erreurs. `scripts/check.sh apps/mh_cli` = OK. Reste : commit (humain) ; exécution sur ISO réelle à valider (`dart run apps/mh_cli/bin/mhtk.dart index --iso local/MHP3.iso`).

## Fait

- Squelette T0 vérifié [compilé] : Dart 3.9.0, `dart pub get` OK, `scripts/check.sh` = OK. Flutter/FVM absents (studio non créé).

## Questions ouvertes

- Licence globale GPLv3+ validée par l'humain (T6). `MHP3_ISO` et `local/MHP3.iso` encore absents.
- `apps/mh_studio` : créé par `pwsh scripts/setup_studio.ps1` (FVM). Les deps Flutter (Riverpod, etc.) seront proposées avant ajout. `apps/mh_patcher` et `server/mh_server` restent à créer à leur phase.
- `scripts/check.sh` appelle `dart`/`flutter` : les lancer avec `.fvm/flutter_sdk/bin` dans le PATH (le Dart de FVM sert pour tout le workspace).
- `lints: ^5.0.0` et `test: ^1.25.0` supposent Dart ≥ 3.6 ; à confirmer avec `dart --version`.

## Décisions

Voir `docs/DECISIONS/`.

## À valider par l'humain sur données réelles

- Après T4/T5 (inclut l'ISO réelle : MD5 reconnu + offset DATA.BIN = 0x6D50000) : `MHP3_ISO=local/MHP3.iso scripts/check.sh packages/mh_iso --integration`
- Fin de phase 0 : `scripts/check.sh packages/mh_databin --integration`
