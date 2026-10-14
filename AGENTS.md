# AGENTS.md — MHP3rd Translation Toolkit

Instructions pour tout agent de code (GitHub Copilot, Codex, Claude Code, Cursor, etc.) travaillant sur ce dépôt.
À lire en entier avant toute modification. En cas de conflit, ce fichier prime sur les habitudes générales de l'agent.

---

## 1. Le projet en bref

Outil de traduction et de modding de **Monster Hunter Portable 3rd** (PSP, ULJM-05800) et de sa version HD PS3 (NPJB-40001) :

1. lire l'ISO et localiser `PSP_GAME/USRDIR/DATA.BIN` ;
2. déchiffrer `DATA.BIN` (chiffrement dépendant du LBA) et indexer ses fichiers numérotés ;
3. décoder les tables de texte et les importer dans une base de traduction ;
4. traduire (application Flutter desktop, éventuellement serveur collaboratif) ;
5. contrôler la longueur des traductions (octets, pixels, lignes) ;
6. réencoder, rechiffrer **au même LBA**, produire un patch `MHP3RD_DATA.BIN`, l'appliquer sur une **copie** de l'ISO ;
7. revérifier le résultat.

Spécification complète : `docs/ARCHITECTURE.md`. C'est la source de vérité fonctionnelle.

---

## 2. Sources de vérité (par ordre de priorité)

1. `docs/ARCHITECTURE.md` — architecture, formats, contraintes.
2. `docs/PROGRESS.md` — phase en cours, tâches faites et à faire, décisions prises.
3. `docs/FORMATS/*.md` — formats binaires **vérifiés** sur de vrais fichiers (créés au fil du projet).
4. `third_party/` — code de référence en lecture seule, non versionné :
   - `third_party/mhtools/` (codestation, Java, GPLv3) — tables de texte, chiffrement, patch ;
   - `third_party/mhef/` (svanheulen, Python) — `mhef/psp.py`, classe `DataCipher` ;
   - `third_party/mhp3-translation-tools/` (npdawson, Python) — `extractA.py`, `patch-iso.py`.
5. `config/*.yaml` — versions du jeu, codes de contrôle, profils de longueur.

Si une information n'est dans aucune de ces sources : **ne pas l'inventer** (voir §4).

---

## 3. Organisation du dépôt

```
packages/
  mh_binary/     ByteReader/ByteWriter little-endian, alignement, hash
  mh_iso/        ISO 9660, registre des versions
  mh_databin/    chiffrement, TOC, index, PatchFile
  mh_formats/    codecs (string_table_a, puis quest, pac, gim, font)
  mh_budget/     mesure octets / pixels / lignes, profils
  mh_tdb/        base de traduction (drift/SQLite), repositories, sync
  mh_build/      pipeline de build, cache, rapports
apps/
  mh_cli/        CLI `mhtk`
  mh_studio/     Flutter desktop (Riverpod)
  mh_patcher/    patcher autonome utilisateur final
server/
  mh_server/     API REST + WebSocket, PostgreSQL
config/          game_versions.yaml, control_codes.yaml, profiles.yaml
catalog/         libellés de fichiers (métadonnées uniquement)
docs/            ARCHITECTURE.md, PROGRESS.md, FORMATS/, DECISIONS/
third_party/     sources de référence (gitignored)
fixtures/        fichiers SYNTHÉTIQUES générés par les tests
local/           ISO, DATA.BIN, dumps réels (gitignored, jamais commité)
```

Dépendances autorisées entre paquets (sens unique, pas de cycle) :

```
mh_binary ← mh_iso ← mh_databin ← mh_formats ← mh_budget ← mh_build
                                         ↑            ↑
                                       mh_tdb ────────┘
apps/* et server/* dépendent des paquets, jamais l'inverse.
```

`mh_binary`, `mh_iso`, `mh_databin`, `mh_formats`, `mh_budget` sont en **Dart pur** (aucun import Flutter, aucun `dart:ui`).

---

## 4. Règles absolues

### 4.1 Ne jamais inventer

- Aucun champ binaire, offset, magic, code de contrôle, ID de fichier, clé ou algorithme de chiffrement ne doit être deviné.
- Toute structure binaire implémentée doit citer sa source en commentaire : fichier de `third_party/` (chemin + nom de fonction), ou `docs/FORMATS/xxx.md`.
- Si la source manque : **s'arrêter**, écrire la question dans `docs/PROGRESS.md` section « Questions ouvertes », et demander à l'humain.
- Les champs dont le sens est inconnu sont conservés tels quels (`unknownXxx`), jamais « normalisés ».

### 4.2 Données du jeu et légalité

- Ne jamais commiter : ISO, `DATA.BIN`, fichiers extraits, textes japonais du jeu, captures, polices, textures, sauvegardes.
- Les tests unitaires utilisent **uniquement** des fixtures synthétiques générées par code.
- Les tests sur données réelles lisent le chemin depuis la variable d'environnement `MHP3_ISO` (ou `MHP3_DATABIN`) et sont ignorés (`skip`) si elle est absente.
- Ne jamais afficher de gros extraits de texte du jeu dans les logs, issues ou PR.

### 4.3 Sécurité des fichiers

- **L'ISO source n'est jamais ouvert en écriture.** Toute écriture se fait sur une copie (`IsoImage.cloneTo`).
- Vérifier le MD5 de l'ISO contre `config/game_versions.yaml` avant toute opération de patch.
- Vérifier que l'offset de `DATA.BIN` calculé par ISO 9660 est égal à celui du registre ; sinon, erreur.

### 4.4 Contraintes binaires non négociables

- Tous les entiers sont **little-endian** sauf preuve contraire documentée.
- Secteur = **2048 octets**. Les tailles de blocs de patch sont alignées sur le secteur (et donc multiples de 1024, exigence du patcher de référence).
- Un fichier rechiffré l'est **au LBA d'origine**. Aucune relocation en v1.
- Taille reconstruite alignée **≤ `slotBytes`** : erreur bloquante.
- Politique `strict` par défaut : taille reconstruite **≤ taille originale** ; la politique `slot` n'est autorisée que pour les fichiers de la liste blanche `config/validated_files.yaml`.
- `measure(model)` doit être **exactement** égal à `encode(model).length`.

### 4.5 Round-trip bit à bit

- Pour tout codec : `encode(decode(f)) == f` sur tout fichier non modifié.
- Pour le chiffrement : `encrypt(decrypt(x, lba), lba) == x`.
- Un codec qui échoue ce test n'est pas « presque fini » : il est faux.
- Le codec `string_table_a` conserve les offsets d'origine et les alias (plusieurs offsets → même chaîne). Ne pas reproduire l'approximation séquentielle de mhtools.

### 4.6 Licences

- mhtools est sous **GPLv3**. Tout code porté ou traduit depuis mhtools va dans un fichier portant l'en-tête GPLv3 et une mention de l'origine ; signaler le portage dans `docs/DECISIONS/`.
- Avant de porter du code de mhef ou d'un autre projet, vérifier sa licence dans `third_party/<projet>/LICENSE` et la noter dans `docs/DECISIONS/`.
- Ne jamais supprimer un en-tête de licence ou une mention d'auteur.

---

## 5. Méthode de travail

1. Lire `docs/PROGRESS.md` et identifier la phase en cours. **Ne travailler que sur cette phase.**
2. Proposer un plan court (fichiers touchés, tests prévus) avant d'écrire du code non trivial.
3. Écrire les tests en même temps que le code (ou avant).
4. Petits incréments : une fonctionnalité = un commit cohérent qui compile et passe les tests.
5. Mettre à jour `docs/PROGRESS.md` à la fin de chaque tâche (fait, reste, questions).
6. Toute décision d'architecture non prévue par `ARCHITECTURE.md` → fiche courte dans `docs/DECISIONS/NNNN-titre.md` (contexte, décision, alternatives).
7. Ne pas modifier `docs/ARCHITECTURE.md` sans demande explicite ; proposer le changement dans une fiche de décision.

### Phases (rappel, détail dans ARCHITECTURE.md §12)

| Phase | Périmètre | Critère de sortie |
|---|---|---|
| 0 | `mh_binary`, `mh_iso`, chiffrement `mh_databin` | Round-trip du chiffrement sur 100 % de `DATA.BIN` |
| 1 | Codec `string_table_a` (alias), import/export mhtools | Round-trip bit à bit de toutes les tables détectées |
| 2 | `mh_tdb` SQLite, CLI, budget niveaux 1 et 2, build ISO | ISO patché avec quelques chaînes modifiées qui démarre |
| 3 | `mh_studio` | Traduction d'un fichier complet dans l'outil |
| 4 | Police, budget pixels/lignes, tests PPSSPP | Rapport de débordement fiable sur les menus |
| 5 | `mh_server`, sync, rôles | 3 traducteurs sur un fichier sans perte |
| 6 | Quêtes, GIM, version HD | Build multi-version depuis une base |

---

## 6. Commandes

```bash
# Installation
dart pub get                         # à la racine (pub workspace)
melos bootstrap                      # si melos est utilisé

# Qualité
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
melos run test                       # tests unitaires de tous les paquets

# Par paquet
cd packages/mh_formats && dart test -x integration

# Tests sur données réelles (machine locale uniquement)
MHP3_ISO=local/MHP3.iso dart test -t integration

# Génération de code (drift, freezed, riverpod_generator)
dart run build_runner build --delete-conflicting-outputs

# CLI
dart run apps/mh_cli/bin/mhtk.dart --help
```

Les scripts `melos run <x>` sont définis dans le `pubspec.yaml`/`melos.yaml` racine. Si une commande listée ici n'existe pas encore, la créer plutôt que d'en inventer une autre.

---

## 7. Conventions de code Dart

- Dart 3, null safety, `strict-casts`, `strict-inference`, `strict-raw-types` activés ; lints `very_good_analysis` ou `lints/recommended` + règles du dépôt.
- Aucun `dynamic` dans les paquets cœur. Pas de `!` sans commentaire justifiant pourquoi la valeur ne peut pas être nulle.
- Données binaires : `Uint8List` et `ByteData` ; jamais `List<int>` dans les API publiques des paquets cœur.
- Modèles immuables (`final class`, champs `final`, `copyWith` si nécessaire) ; états et résultats en `sealed class`.
- Erreurs typées : `FormatError`, `BudgetError`, `CryptoError`, `PatchError`, `IsoError` (héritant d'une `MhError` commune), avec offset et ID de fichier dans le message.
- Pas de lecture hors bornes silencieuse : tout `ByteReader` vérifie les bornes et lève `FormatError`.
- I/O asynchrone dans les apps, synchrone autorisé dans les paquets cœur pour les traitements en mémoire.
- Nommage des fichiers en `snake_case.dart`, un type public principal par fichier.
- Commentaires de format : décrire la structure octet par octet (offset, taille, type, signification, source).
- Flutter (`mh_studio`) : Riverpod (avec générateur), aucune logique métier dans les widgets, tout passe par les paquets.

Exemple de commentaire de format attendu :

```dart
/// En-tête d'un fichier de tables de texte (codec A).
///
/// | Offset | Taille | Type | Champ           |
/// |--------|--------|------|-----------------|
/// | 0x00   | 4      | u32  | tablesCount     |
/// | 0x04   | 4      | u32  | unknownHeader   |
/// | 0x08   | 4 × n  | u32  | tableOffsets    | 0xFFFFFFFF = table nulle
///
/// Source : third_party/mhtools/src/dec/ExtractPluginA.java (extract)
```

---

## 8. Tests

- Framework : `package:test` (paquets Dart) et `flutter_test` (studio).
- Tags déclarés dans `dart_test.yaml` : `integration` (données réelles), `slow`.
- Obligatoire pour chaque codec :
  - round-trip sur fixtures synthétiques ;
  - test de propriété `measure == encode().length` ;
  - cas limites : table nulle, chaîne vide, alias, fichier tronqué, offset hors bornes ;
  - test `integration` de round-trip sur tous les fichiers réels détectés.
- Les fixtures sont **générées** par des builders de test (`fixtures/builders/`), pas copiées depuis le jeu.
- Un test qui échoue n'est jamais désactivé ou affaibli pour faire passer la CI. Le signaler.

---

## 9. Définition de « terminé »

Une tâche est terminée seulement si :

- [ ] `dart format`, `dart analyze --fatal-infos` sont propres ;
- [ ] les tests unitaires passent ;
- [ ] les tests `integration` concernés ont été lancés localement par l'humain, ou la tâche est explicitement marquée « à valider sur données réelles » dans `PROGRESS.md` ;
- [ ] chaque structure binaire cite sa source ;
- [ ] `docs/PROGRESS.md` est à jour ;
- [ ] aucune donnée du jeu n'est ajoutée au dépôt (`git status` vérifié).

Ne jamais annoncer « ça fonctionne » sans avoir exécuté les tests. Distinguer clairement : « compilé », « testé sur fixtures », « testé sur données réelles », « testé en jeu ».

---

## 10. Quand s'arrêter et demander

S'arrêter et poser la question à l'humain si :

- un format binaire, un code de contrôle ou un ID de fichier n'est documenté nulle part ;
- le round-trip échoue et la cause n'est pas évidente après analyse ;
- une modification toucherait l'ISO source, la politique de budget ou la licence ;
- une tâche sort de la phase en cours ;
- une dépendance externe nouvelle est nécessaire (justifier : licence, maintenance, alternative).

---

## 11. Git

- Branches : `phase-N/sujet-court` (ex. `phase-1/string-table-aliases`).
- Commits au format Conventional Commits, en anglais : `feat(mh_formats): preserve string offset aliases`.
- Un commit = un changement cohérent qui compile.
- `.gitignore` doit couvrir : `local/`, `third_party/`, `*.iso`, `*.ISO`, `DATA.BIN`, `*.bin.enc`, `MHP3RD_DATA.BIN`, `out/`, `*.sqlite`, `.dart_tool/`, `build/`.
- Avant chaque commit : vérifier qu'aucun fichier binaire de plus de 100 Ko n'est ajouté sans raison.

---

## 12. Glossaire

| Terme | Sens |
|---|---|
| `DATA.BIN` | Conteneur chiffré unique des fichiers du jeu (`PSP_GAME/USRDIR/`) |
| LBA | Numéro de secteur de 2048 octets ; paramètre du chiffrement |
| TOC | Table des matières en tête de `DATA.BIN` |
| ID de fichier | Numéro mhtools (base 1) ; ID hexa des chargeurs de mods = ID − 1 sur 4 chiffres |
| Slot | Espace alloué à un fichier dans `DATA.BIN` (offset suivant − offset courant) |
| Codec A / `string_table_a` | Format de tables de texte (décodeur 1 de mhtools) |
| Alias | Plusieurs offsets d'une table pointant vers la même chaîne |
| Patch `MHP3RD_DATA.BIN` | `u32 count`, `count × (u32 offset, u32 length)`, pad 16, données |
| Politique `strict` / `slot` | Limite de taille = taille originale / taille du slot |
| Profil de longueur | Contraintes d'affichage (px, lignes) par contexte |
