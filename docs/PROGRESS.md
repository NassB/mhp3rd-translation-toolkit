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

## Phase 1 — Codec `string_table_a` (tâches)

Critère de sortie : round-trip bit à bit de toutes les tables détectées (test `integration`).

- [x] **T10 Référence `string_table_a`** [compilé] — `docs/FORMATS/string_table_a.md` écrit depuis mhtools/extractA.py (structure, divergences Java/Python, pièges). **Non vérifié sur fichiers réels** ; 4 questions ouvertes listées dans la fiche (unknownHeader, endData, alias, chaînes vides), à trancher en T11/T13 via `/explore-data`. Reste : commit (humain).
- [x] **T11 Décodeur `string_table_a`** [fixtures] — `decodeStringTableA` + modèle (`StringTableFile`/`StringTable`/`StringSlot`) dans `packages/mh_formats/lib/src/`, builder synthétique `test/support/string_table_a_builder.dart`. Layout vérifié sur l'ID 17 réel via `/explore-data` (script `packages/mh_databin/tool/explore_string_table_a.dart`) ; layout non canonique → `FormatError`. `tokens` reportés à T14. `scripts/check.sh packages/mh_formats` = OK. Décodage réel non encore lancé (T13). Reste : commit (humain).
- [x] **T12 Encodeur `string_table_a`** [fixtures] — `encodeStringTableA`/`measureStringTableA` (`packages/mh_formats/lib/src/string_table_a_encoder.dart`) : offsets canoniques recalculés, alias conservés (`aliasOf` valide : index antérieur non aliasé), chaîne contenant 0x00 → `FormatError`. Tests : round-trip (table nulle/vide, chaîne vide, alias, endData, fichier vide), `measure == encode().length` après modification, rejets. Les cas « tronqué/hors bornes » relèvent du décodeur (T11). `scripts/check.sh packages/mh_formats` = OK. Reste : commit (humain) ; round-trip réel en T13.
- [x] **T13 Test `integration` round-trip** [réel] — `packages/mh_formats/test/string_table_a_roundtrip_integration_test.dart` : scanne tout `DATA.BIN`, détection = décodage strict réussi, vérifie `encode(decode(x)) == x` et `measure == length`. Lancé sur l'ISO réelle (lecture seule) : ~650 fichiers détectés (ID 17, 1871–2819, 4192–4590, 5486–5653), 0 échec. Critère de sortie phase 1 à confirmer par l'humain. Dép. dev `mh_iso` ajoutée à `mh_formats`. Reste : commit (humain).
- [x] **T14 Import/export mhtools** [fixtures] — `exportMhtoolsDump`/`importMhtoolsDump` (`mhtools_dump.dart`, `mhtools_text.dart`, en-tête GPLv3+) : dossier en mémoire (`filelist` + `.txt` + `enddata`), import appliqué sur le modèle d'origine (offsets/alias conservés). Tests `mhtools_dump_test.dart`. `scripts/check.sh packages/mh_formats` = OK. Pas d'E/S disque (CLI en phase 2). Reste : commit (humain) ; critère de sortie phase 1 à confirmer par l'humain (T13).

- **Correction (2026-10-15)** : le scan T13 ne comptait pas ~650 tables mais 711 fichiers dont **703 faux positifs** (`tablesCount = 0`, binaires acceptés à tort). Seuls 8 vrais `string_table_a` : IDs 17 et 2813–2819. Le critère de sortie phase 1 repose donc sur 8 fichiers ; détection à durcir (voir questions ouvertes). `endData` de l ID 17 (1 043 octets) toujours non identifié.

## Phase 2 — Base locale, budget, build ISO (tâches)

Critère de sortie : ISO patché avec quelques chaînes modifiées, qui démarre (test en jeu par l'humain).
Découpage fait le 2026-10-15 depuis ARCHITECTURE §7, §8.1–8.3, §9, §5.3. Aucune tâche commencée.

- [x] **T15 Tokens texte + newline** [réel] — `text_token.dart` (`Token` sealed : `TextToken`, `NewlineToken`; `tokenizeText`/`detokenizeText`/`tokensByteLength`, `StringSlot.tokens`) ; aucun code de contrôle (0 dans les données réelles, pas de `control_codes.yaml`), `
` seul est un jeton. Tests `text_token_test.dart` + round-trip des jetons et longueur exacte sur les 8 fichiers réels (`--integration` OK). Reste : commit (humain). T17/T19 n'ont plus T15 comme prérequis bloquant.
- [x] **T16 `mh_budget` niveaux 1 et 2** [fixtures] — `evaluateFileBudget` → `BudgetReport` (statut `ok`/`slotOverflow`/`bufferOverflow`/`policyNotAllowed`, `toJson` §8.6, `requireOk` lève `BudgetError`/`PatchError`) ; `BudgetError`/`BudgetLevel` dans `mh_binary`. Politique `slot` refusée hors liste blanche (Set passé par l'appelant ; `config/validated_files.yaml` n'existe pas encore, chargement en T22). `strict` compare à la taille non alignée. Pas de wrapper de mesure : T21 appellera `measureStringTableA` directement. `scripts/check.sh packages/mh_budget` et `mh_binary` = OK. Reste : commit (humain).
- [x] **T17 `PatchFile`** [fixtures] — `packages/mh_databin/lib/src/patch_file.dart` (`PatchBlock`, `serialize`, `parse` borné, `validate(DataBinIndex)`), fiche `docs/FORMATS/patch.md`, `docs/DECISIONS/0003-patchfile-gpl.md`. Queue `install_tables` ignorée (sens inconnu). Slots vides de la TOC ignorés pour la validation. `scripts/check.sh packages/mh_databin` = OK. Pas confronté à un patch réel ni à un patcheur tiers. Reste : commit (humain).
- [x] **T18 `applyPatch` sur copie d'ISO** [fixtures] — `packages/mh_databin/lib/src/patch_apply.dart` : `applyPatch(source, patch, index, outPath:)` valide (`PatchFile.validate` + bornes `DATA.BIN`) avant création, `cloneTo` (refuse tout fichier existant, source comprise), écriture à `dataBin.offset + offset` en `FileMode.append`. Fichier partiel conservé si l'écriture échoue. Tests sur ISO synthétique (builder de `mh_iso` importé par chemin relatif) : blocs en place, voisins et source intacts, sortie existante refusée, patch invalide sans fichier. `scripts/check.sh packages/mh_databin` = OK (Windows). **À vérifier** : comportement de `FileMode.append` + `setPosition` sur POSIX (non testé ici) ; MD5 de la copie non revérifié (étape 10 du build en T21/T23). Reste : commit (humain).
- [x] **T19 `mh_tdb` schéma drift/SQLite** [fixtures] — tables `game_file`, `source_string`, `translation` (CHECK sur `status`), `build` (`packages/mh_tdb/lib/src/tables/`), `TdbDatabase` (`openInMemory`/`openFile`, `PRAGMA foreign_keys = ON`), code généré `tdb_database.g.dart` commité (`dart run build_runner build`). Dépendances : `docs/DECISIONS/0004-dependance-drift.md`. `source_text` = UTF-8 avec `
` réel. FK déclarées par `customConstraint` car drift_dev 2.31 ignore `references(...)` ("should be a simple class name", cause non élucidée, peut-être analyzer rétrogradé). Reportées : `translation_history`, `glossary_term`, `comment`, `length_profile`. `scripts/check.sh` (dépôt entier) = OK sous Windows (`winsqlite3.dll`) ; SQLite système à fournir sous Linux/macOS. Reste : commit (humain).
- [x] **T20 Import dump mhtools → base** [fixtures] — `packages/mh_tdb/lib/src/import_mhtools.dart` : `importSourceFile` (`game_file` + `source_string`, SHA-1 des octets, `alias_of`, transaction, refuse un fichier déjà importé) et `importMhtoolsTranslations` (applique le dump via `importMhtoolsDump`, slots non alias, texte identique à la source ignoré, réimport = `revision + 1` si changement, statut en paramètre `draft` par défaut, tout ou rien). `TdbError` ajouté à `mh_binary` ; deps `mh_binary` et `crypto` pour `mh_tdb`. Tests en base mémoire. `scripts/check.sh` (dépôt entier) = OK. Non lancé sur les 8 vrais fichiers (pas de CLI avant T22) ; l'appelant devra fournir `lba`/`slotBytes`/`origBytes` de l'index. Reste : commit (humain).
- [x] **T21a `mh_build` : `buildPatch` (Select→Patch)** [fixtures] — `packages/mh_build/lib/src/build_patch.dart` : traductions éligibles (`eligibleTranslations`, `mh_tdb/lib/src/build_queries.dart`, statut ≥ `minStatus`), décodage de l'original (lu par l'appelant via `PlainSlotReader`), remplacement des slots non alias (SHA-1 de la source vérifié, base périmée = `TdbError`), encodage, budget niveaux 1-2 par fichier, **disposition « tables | zéros | endData » : `endData` reste à sa position d'origine** (comportement de `RebuildPluginA`, décision humaine du 2026-10-15), chiffrement au LBA (sauf fichiers en clair), `PatchFile.validate`. Tout ou rien : un dépassement → `patch == null` et rapports de tous les fichiers. Tests : `build_patch_test.dart` (8). `scripts/check.sh` (dépôt entier) = OK. **Hypothèse non vérifiée** : le contenu de `endData` (1 043 octets sur l'ID 17) peut contenir des offsets absolus ; seule la position est préservée. Reste : commit (humain).
- [x] **T21b `mh_build` : Apply→Report** [fixtures] — `run_build.dart` : `runBuild` enchaîne instantané `tdbRevision` (somme des `revision` des `translation`, décision humaine du 2026-10-15), `buildPatch`, `applyPatch` sur copie, **relecture de l'artefact** (bloc relu = patch, déchiffrement, décodage, texte de chaque traduction éligible), rapport JSON (§8.6 + `iso_md5`, `tdb_revision`, `verify_errors`) et ligne `build` (`ok` / `nothing_to_build` / `budget_exceeded` / `verify_failed`). Budget dépassé ou rien à faire : aucun ISO écrit. `recordBuild`/`tdbRevision` dans `mh_tdb`, `BuildResult.applied`. Tests sur ISO synthétique (copie vérifiée, octets hors bloc inchangés, source intacte, sortie existante refusée). `scripts/check.sh` (dépôt entier) = OK. **Non testé** : l'issue `verify_failed` (difficile à provoquer sans panne d'écriture) ; cache par fichier et manifeste signé reportés. Reste : commit (humain).
- [x] **T22a CLI `mhtk` : `init`, `extract`, `status`** [réel] — `apps/mh_cli/lib/src/{project,init_command,extract_command,status_command}.dart` : projet = dossier `project.json` + `tdb.sqlite` ; `init` (MD5/offset vérifiés, refuse un projet existant), `extract` (critère durci, relançable), `status` (`tdbStatus`, `importedFileIds` dans `mh_tdb`). Tests sur ISO synthétique. **Lancé sur l ISO réelle** (projet dans `out/`, lecture seule de l ISO) : 5 955 fichiers dans `DATA.BIN`, 8 `string_table_a` détectés et importés, 15 051 chaînes (= exploration de T15). `scripts/check.sh apps/mh_cli` = OK. Reste : commit (humain).
- [ ] **T22b CLI `mhtk import`** [fixtures] — `--project`, `--from <dossier de dump>`, `--file <id>`, `--locale`, `--status` ; la disposition multi-fichiers des dumps mhtools n’est pas documentée (un dossier = un fichier).
- [ ] **T22c CLI `mhtk budget` et `build`** [fixtures] — `--file <id>`, `--target iso`, `--policy`, chargement de `config/validated_files.yaml` (à créer), `runBuild`. Cibles `plugin`/`delta`, `export`, `verify` hors phase 2.
- [ ] **T23 Build réel minimal** [réel] — quelques chaînes modifiées → ISO copie dans `out/` → vérif ré-extraction (étape 10) ; démarrage en jeu (PPSSPP) par l'humain.

## Fait

- Squelette T0 vérifié [compilé] : Dart 3.9.0, `dart pub get` OK, `scripts/check.sh` = OK. Flutter/FVM absents (studio non créé).

## Questions ouvertes

- **T15 / codes de contrôle** (2026-10-15) : sur 711 `string_table_a` détectés (15 051 slots, `local/explore/text_content.txt`), 100 % UTF-8 valide, **0 octet de contrôle** hors `\n`, 0 PUA, 0 alias, 0 littéral `<NEWLINE>`/`<EMPTY STRING>`. `config/control_codes.yaml` n'existe pas et rien ne justifie d'en inventer un. Tokens = `\n` seulement ? À trancher ; périmètre de T15 à redéfinir avant de coder.
- **Faux positifs de détection : confirmés et corrigés** [réel] (explore-data, `local/explore/ascii_files.txt`) : les 703 fichiers hors IDs 17 et 2813–2819 ont `tablesCount = 0` (binaires de 2 Ko à 1,5 Mo). Critère proposé : `count >= 1`, au moins une table non nulle et un slot non vide. Détecteur du test T13 durci (table non nulle + slot non vide) ; `scripts/check.sh packages/mh_formats --integration` OK sur l ISO réelle : détectés = [17, 2813–2819], round-trip et `measure` OK. Le décodeur reste inchangé (accepte toujours tablesCount = 0).
- Licence globale GPLv3+ validée par l'humain (T6). `MHP3_ISO` et `local/MHP3.iso` encore absents.
- `apps/mh_studio` : créé par `pwsh scripts/setup_studio.ps1` (FVM). Les deps Flutter (Riverpod, etc.) seront proposées avant ajout. `apps/mh_patcher` et `server/mh_server` restent à créer à leur phase.
- `scripts/check.sh` appelle `dart`/`flutter` : les lancer avec `.fvm/flutter_sdk/bin` dans le PATH (le Dart de FVM sert pour tout le workspace).
- `lints: ^5.0.0` et `test: ^1.25.0` supposent Dart ≥ 3.6 ; à confirmer avec `dart --version`.

## Décisions

Voir `docs/DECISIONS/`.

## À valider par l'humain sur données réelles

- Après T4/T5 (inclut l'ISO réelle : MD5 reconnu + offset DATA.BIN = 0x6D50000) : `MHP3_ISO=local/MHP3.iso scripts/check.sh packages/mh_iso --integration`
- Fin de phase 0 : `scripts/check.sh packages/mh_databin --integration`

## Validation phase 0 sur données réelles (2026-10-15) [réel]

- ISO ULJM05800 de l'humain : MD5 `40ee8e11…` ≠ référence `8e19a966…` ; ID, taille et offset DATA.BIN (0x6D50000) identiques → MD5 de référence du registre (anciennes entrées patch-iso.py et NPJB40001_HD retirées) (`docs/DECISIONS/0002-variante-md5-uljm05800.md`). Cause de la différence de MD5 non identifiée.
- `packages/mh_iso` `-t integration` : OK.
- `packages/mh_databin` `-t integration` : OK (round-trip `encrypt(decrypt(x, lba), lba) == x` sur tous les fichiers chiffrés).
- Correction découverte sur données réelles : la TOC contient des entrées égales (slots vides, `slotBytes = 0`). Contrainte « strictement croissant » (non sourcée) remplacée par « non décroissant » + test synthétique.
- **Critère de sortie phase 0 : validé.** Reste : commit (humain), exécuter `mhtk index --iso local/MHP3.iso` (T9).

## Validation phase 1 sur données réelles (2026-10-15) [réel]

- `scripts/check.sh packages/mh_formats --integration` lancé par l'humain sur l'ISO réelle : OK (round-trip bit à bit de tous les `string_table_a` détectés, ~650 fichiers).
- **Critère de sortie phase 1 : validé.** Reste : commit (humain). Phase 2 : tâches à découper (ARCHITECTURE.md §12).
