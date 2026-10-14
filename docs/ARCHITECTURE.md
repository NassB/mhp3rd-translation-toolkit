# MHP3rd Translation Toolkit — Architecture logicielle

Outil de traduction et de modding pour Monster Hunter Portable 3rd (ULJM-05800, et sa version HD PS3 NPJB-40001)

Version du document : 1.0 — octobre 2026

---

## 1. Contexte et état de l'art

### 1.1 Ce qui existe déjà

| Projet | Apport | Limites pour notre besoin |
|---|---|---|
| [mhtools (codestation)](https://github.com/codestation/mhtools) | Référence historique en Java : déchiffrement de `DATA.BIN`, extraction et reconstruction des tables de texte, quêtes, sauvegardes, création de patch | Outil CLI orienté fichiers `.txt`, pas de base de traduction, pas de contrôle de longueur, décodeurs identifiés par numéro (1 à 7) sans détection automatique ([usage de MHTools.java](https://www.javatips.net/api/mhtools-master/src/base/MHTools.java)) |
| [mhef (svanheulen)](https://github.com/svanheulen/mhef/blob/master/mhef/psp.py) | Implémentation Python lisible du chiffrement de `DATA.BIN` (classe `DataCipher`), des quêtes et des sauvegardes | Bibliothèque, pas de pipeline |
| [mhp3-translation-tools (npdawson)](https://github.com/npdawson/mhp3-translation-tools) | Scripts Python d'extraction (`extractA.py`, `extractC.py`) et d'application du patch dans l'ISO (`patch-iso.py`) | Scripts ad hoc, s'appuie sur mhtools |
| Patch TeamMaverickOne (v5.0 puis v6.x communautaire) | Traduction anglaise complète ; distribution par patcher ISO ou par plugin CFW `mhp3patch.prx` adapté de codestation ([GameBrew](https://www.gamebrew.org/wiki/Monster_Hunter_Portable_3rd_Translation_Patch_PSP)) ; v6.3.0 publiée le 1er octobre 2026 avec harmonisation terminologique sur MH3U/MHGU ([CDRomance](https://cdromance.org/psp/monster-hunter-portable-3rd-english-patched-2/)) | Outillage interne non publié, workflow peu documenté |
| [MHP3rd Game File List (Kurogami2134)](https://github.com/Kurogami2134/MHP3rd-Game-FIle-List) | Index des fichiers numérotés de `DATA.BIN` et guide de modding | Pas d'index exhaustif des fichiers de texte |

### 1.2 Faits techniques sur lesquels repose l'architecture

1. Tous les fichiers du jeu sont dans un unique conteneur `PSP_GAME/USRDIR/DATA.BIN`, sans noms ni arborescence : on n'obtient que des fichiers numérotés ([guide de modding](https://github.com/Kurogami2134/MHP3rd-Game-FIle-List/blob/main/guide/guide.md)).
2. `DATA.BIN` est chiffré ; la fonction `decrypt(buff, lba)` de mhef prend l'adresse de bloc logique (LBA) en paramètre, et la taille de la table des matières se calcule à partir du premier mot déchiffré multiplié par 2048 ([mhef/psp.py](https://github.com/svanheulen/mhef/blob/master/mhef/psp.py)). Conséquence : le chiffré d'un fichier dépend de sa position. On ne peut pas déplacer un fichier sans le rechiffrer.
3. Les tables de texte (décodeur A de mhtools) ont la structure suivante ([ExtractPluginA.java](https://github.com/codestation/mhtools/blob/master/src/dec/ExtractPluginA.java)) :
   - `u32 tables_count`, `u32 inconnu`, puis `tables_count × u32` offsets de tables (`0xFFFFFFFF` = table nulle) ;
   - pour chaque table : un tableau de `u32` offsets terminé par `0xFFFFFFFF`, puis les chaînes terminées par `\0`, la table se termine par un double `\0` ;
   - une zone de fin (`enddata.bin`) conservée telle quelle.
   - mhtools écrit les chaînes en UTF-8 et remplace `\n` par `<NEWLINE>`, et les chaînes vides par `<EMPTY STRING>`.
4. Le fichier de patch `MHP3RD_DATA.BIN` produit par `--create-patch` a ce format : `u32 num_files`, puis `num_files × (u32 offset, u32 length)` en little-endian, en-tête aligné sur 16 octets, puis les données concaténées. Le patcher écrit chaque bloc à `offset_DATA.BIN_dans_ISO + offset` ; `DATA.BIN` commence à `0x6D50000` dans l'ISO PSP et à `0x6D60000` dans l'ISO HD, et les longueurs sont des multiples de 1024 octets ([patch-iso.py](https://github.com/npdawson/mhp3-translation-tools/blob/main/patch-iso.py)).
5. Il n'y a donc aucune relocation : chaque fichier modifié est réécrit en place. Sa taille chiffrée doit tenir dans l'emplacement d'origine. C'est la contrainte de longueur la plus dure du projet.
6. mhtools est sous GPLv3 ([en-tête d'ExtractPluginA.java](https://github.com/codestation/mhtools/blob/master/src/dec/ExtractPluginA.java)) : tout portage direct de son code impose la GPLv3 au module concerné.

---

## 2. Principes directeurs

1. **Non destructif** : l'ISO source n'est jamais modifié ; on produit toujours un artefact nouveau (ISO patché, patch plugin, delta).
2. **Round-trip bit à bit** : `decode(encode(x)) == x` et `encode(decode(f)) == f` pour chaque fichier original non modifié. C'est le test de non-régression principal.
3. **Codecs en plugins** : chaque format (table de texte, quête, conteneur PAC, texture GIM) est un codec isolé, avec détection, décodage, encodage et calcul de budget.
4. **Budget mesuré avant la compilation** : toute traduction est évaluée en temps réel (octets, pixels, lignes) dès la saisie, pas au moment du build.
5. **Base de traduction comme source de vérité** : les fichiers `.txt` de mhtools ne sont qu'un format d'import/export.
6. **Reproductibilité** : un build est entièrement déterminé par (hash de l'ISO, révision de la base, version du toolkit, profil de build).
7. **Séparation légale** : aucune donnée Capcom (ISO, binaires, textes japonais) dans le dépôt public ; seuls le code, les métadonnées et les traductions sont versionnés.

---

## 3. Vue d'ensemble

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Couche présentation                            │
│  mh-studio (Flutter desktop)   mh-cli (Dart AOT)   mh-web (Flutter web)│
└───────────────┬─────────────────────────┬──────────────────────────────┘
                │                         │
┌───────────────▼─────────────────────────▼──────────────────────────────┐
│                         Couche application                             │
│  ProjectService  ExtractionPipeline  BuildPipeline  QAService  SyncSvc │
└──┬──────────────┬────────────────┬───────────────┬───────────────┬─────┘
   │              │                │               │               │
┌──▼─────┐  ┌─────▼──────┐  ┌──────▼──────┐  ┌─────▼──────┐  ┌─────▼─────┐
│ mh_iso │  │ mh_databin │  │ mh_formats  │  │ mh_budget  │  │  mh_tdb   │
│ ISO9660│  │ Crypto+TOC │  │ Codecs      │  │ Longueurs  │  │ Base trad │
│ lecture│  │ Index/LBA  │  │ StringTable │  │ Octets/px  │  │ SQLite /  │
│ hash   │  │ Patch I/O  │  │ Quest, PAC  │  │ Lignes     │  │ Postgres  │
└────────┘  └────────────┘  └─────────────┘  └────────────┘  └─────┬─────┘
                                                                   │
                                                     ┌─────────────▼─────────┐
                                                     │ mh-server (optionnel) │
                                                     │ API REST + WebSocket  │
                                                     │ PostgreSQL, Docker    │
                                                     └───────────────────────┘
```

Flux principal :

```
ISO ──► [mh_iso] localiser DATA.BIN ──► [mh_databin] déchiffrer TOC + fichiers
    ──► [mh_formats] détecter/décoder les tables ──► [mh_tdb] importer les entrées
    ──► traduction (studio / web) + [mh_budget] en continu
    ──► [BuildPipeline] encoder ──► valider budget ──► rechiffrer (LBA d'origine)
    ──► écrire patch MHP3RD_DATA.BIN ──► appliquer sur une copie de l'ISO
    ──► [QAService] re-extraire et comparer à la base ──► tests PPSSPP
```

---

## 4. Module `mh_iso` — accès à l'image disque

### Responsabilités

- Lire l'ISO en ISO 9660 (descripteur de volume primaire au secteur 16, secteurs de 2048 octets).
- Localiser `PSP_GAME/USRDIR/DATA.BIN` en parcourant les répertoires, et ne pas se fier uniquement aux offsets codés en dur.
- Identifier la version (MD5 de l'ISO, `PARAM.SFO`, `UMD_DATA.BIN`) et la confronter à un registre de versions connues.

### Registre des versions

```yaml
# config/game_versions.yaml
- id: ULJM05800
  platform: psp
  iso_md5: 8e19a966356a83b8b395957671494bd8
  databin_iso_offset: 0x6D50000   # vérifié par parcours ISO9660
- id: NPJB40001_HD
  platform: ps3
  iso_md5: 8328f5774e3106953a9560a0b18c2d49
  databin_iso_offset: 0x6D60000
```

Les hashes et offsets ci-dessus sont ceux utilisés par [patch-iso.py](https://github.com/npdawson/mhp3-translation-tools/blob/main/patch-iso.py). L'offset calculé par le parcours ISO 9660 doit être égal à l'offset du registre, sinon le build est refusé.

### Interface

```dart
abstract interface class IsoImage {
  String get path;
  GameVersion get version;
  IsoEntry locate(String path);                 // ex. 'PSP_GAME/USRDIR/DATA.BIN'
  Stream<List<int>> openRead(IsoEntry e, {int start = 0, int? end});
  Future<IsoImage> cloneTo(String outPath);     // copie avant patch
}
```

---

## 5. Module `mh_databin` — conteneur, chiffrement, index

### 5.1 Chiffrement

- Porter `DataCipher` (mhef) ou le décrypteur de mhtools en Dart, sous forme de fonction pure : `Uint8List decrypt(Uint8List data, int lba)` et `encrypt(...)`.
- Tester le portage contre l'implémentation de référence sur un échantillon de fichiers (vecteurs de test générés localement, jamais versionnés).
- Le chiffrement est dépendant du LBA (voir 1.2) : on stocke dans l'index le LBA d'origine de chaque fichier et on rechiffre toujours au même LBA.

### 5.2 Table des matières et index

L'index est la pièce centrale : il associe un identifiant stable à chaque fichier.

```dart
final class DataBinEntry {
  final int id;            // numéro mhtools (base 1)
  final int lba;           // secteur de départ dans DATA.BIN
  final int slotBytes;     // espace alloué = offset suivant - offset courant
  final int sizeBytes;     // taille utile, si connue
  final String sha1Plain;  // hash du contenu déchiffré d'origine
  final String? kind;      // 'string_table', 'quest', 'pac', 'gim', ...
  final String? label;     // libellé humain (catalogue communautaire)
}
```

- `slotBytes` est la valeur que le contrôle de longueur utilise pour le budget de niveau conteneur.
- Le catalogue de libellés s'appuie sur la liste de Kurogami2134 et sur une convention d'ID hexadécimal (ID mhtools − 1, en hexa majuscule sur 4 chiffres, par exemple 2470 → `09A5`), utilisée par les chargeurs de mods ([guide](https://github.com/Kurogami2134/MHP3rd-Game-FIle-List/blob/main/guide/guide.md)).

### 5.3 Lecture et écriture du patch

```dart
final class PatchFile {
  final List<PatchBlock> blocks; // offset relatif à DATA.BIN, données chiffrées

  Uint8List serialize() {
    // u32 count | count × (u32 offset, u32 length) | pad à 16 | données
  }
  static PatchFile parse(Uint8List bytes);
}
```

Contraintes vérifiées à l'écriture :

- `length % 1024 == 0` (exigence du patcher de référence) et, en pratique, alignement sur 2048 (taille de secteur) ;
- `offset` correspond exactement à `lba × 2048` d'une entrée de l'index ;
- `length <= slotBytes` de l'entrée, sans exception ;
- pas de chevauchement entre deux blocs.

---

## 6. Module `mh_formats` — codecs

### 6.1 Contrat d'un codec

```dart
abstract interface class FormatCodec<T> {
  String get id;                              // 'string_table_a'
  double sniff(Uint8List plain);              // 0..1, confiance de détection
  T decode(Uint8List plain);
  Uint8List encode(T model);
  SizeReport measure(T model);                // taille exacte avant encodage
}
```

La détection automatique remplace le choix manuel du numéro de décodeur de mhtools. Pour `string_table_a`, l'heuristique vérifie : `tables_count` raisonnable, offsets croissants et dans les bornes du fichier, présence du marqueur `0xFFFFFFFF` en fin de chaque tableau d'offsets, chaînes décodables en UTF-8, double `\0` final.

### 6.2 Codec des tables de texte (format A)

Modèle fidèle au binaire, plus riche que l'export `.txt` de mhtools :

```dart
final class StringTableFile {
  final int unknownHeader;            // u32 inconnu, conservé tel quel
  final List<StringTable?> tables;    // null = table 0xFFFFFFFF
  final Uint8List endData;            // zone de fin conservée
}

final class StringTable {
  final List<int> originalOffsets;    // conservés pour l'analyse
  final List<StringSlot> slots;
}

final class StringSlot {
  final int index;
  final Uint8List raw;                // octets d'origine (sans \0)
  final List<Token> tokens;           // texte + codes de contrôle
  final int? aliasOf;                 // si plusieurs offsets pointent vers la même chaîne
}
```

Point d'attention important : mhtools ignore le tableau d'offsets à l'extraction et relit les chaînes séquentiellement, puis régénère des offsets séquentiels à la reconstruction ([ExtractPluginA.java](https://github.com/codestation/mhtools/blob/master/src/dec/ExtractPluginA.java)). Si un fichier contient des offsets partagés (deux entrées pointant vers la même chaîne) ou dans un ordre non séquentiel, le round-trip ne sera pas identique. Notre codec :

1. lit les offsets ;
2. construit une carte `offset → chaîne` et détecte les alias ;
3. à l'encodage, réémet les chaînes dans l'ordre d'origine et reproduit les alias ;
4. lève une erreur si la sortie d'un fichier non modifié diffère de l'original.

Le partage d'alias devient aussi un levier d'optimisation (section 8.5).

### 6.3 Tokenisation du texte

Les chaînes ne sont pas du texte brut : elles contiennent des sauts de ligne et potentiellement des séquences de contrôle (couleur, variables, icônes). Elles sont à cartographier empiriquement sur les fichiers réels, car elles ne sont pas documentées publiquement de manière exhaustive.

- Grammaire des tokens déclarée dans un fichier de configuration (`control_codes.yaml`) : séquence d'octets, nom, arité, rendu dans l'éditeur (`{NL}`, `{COLOR:red}`, `{VAR:1}`).
- L'éditeur protège les tokens (non éditables, déplaçables), et la QA vérifie que la traduction contient le même multiensemble de tokens que la source.
- Les marqueurs mhtools `<NEWLINE>` et `<EMPTY STRING>` sont convertis à l'import pour rester compatibles avec les projets existants.

### 6.4 Autres codecs (feuille de route)

| Codec | Usage | Remarques |
|---|---|---|
| `quest_mib` | Quêtes et quêtes événement traduites | Chiffrement spécifique et mise à jour SHA-1 (`--decrypt-quest`, `--update-sha1` dans mhtools) ; un traducteur a signalé des blocages avec un outil tiers sur la version HD ([issue #19](https://github.com/codestation/mhtools/issues/19)), donc il faut un test par plateforme |
| `pac` | Conteneurs génériques | Récursif : un PAC peut contenir des tables de texte |
| `gim` | Textures contenant du texte (titres, menus) | Export PNG, réimport avec quantification de palette |
| `font` | Police et largeurs de glyphes | Source des métriques pour le contrôle en pixels |
| `eboot_strings` | Textes codés en dur dans l'exécutable | Hors périmètre v1 : demande un patch de pointeurs dans l'ELF ou un plugin |

---

## 7. Module `mh_tdb` — base de données de traduction

### 7.1 Deux modes, un seul schéma

| Mode | Stockage | Usage |
|---|---|---|
| Local | SQLite (via `drift`) dans le dossier projet | Traducteur seul, hors ligne |
| Collaboratif | PostgreSQL derrière `mh-server` | Équipe, revue, rôles |
| Hybride | SQLite local + synchronisation | Travail hors ligne puis push/pull |

### 7.2 Schéma

```sql
CREATE TABLE game_file (
  id            INTEGER PRIMARY KEY,   -- ID DATA.BIN
  version_id    TEXT NOT NULL,         -- ULJM05800 / NPJB40001_HD
  codec         TEXT NOT NULL,
  lba           INTEGER NOT NULL,
  slot_bytes    INTEGER NOT NULL,
  orig_bytes    INTEGER NOT NULL,
  label         TEXT,
  context_profile TEXT                 -- profil de longueur par défaut
);

CREATE TABLE source_string (
  id            BIGSERIAL PRIMARY KEY,
  file_id       INTEGER REFERENCES game_file(id),
  table_idx     INTEGER NOT NULL,
  slot_idx      INTEGER NOT NULL,
  source_hash   TEXT NOT NULL,         -- SHA-1 des octets d'origine
  source_text   TEXT NOT NULL,         -- tokenisé ; base privée uniquement
  alias_of      BIGINT REFERENCES source_string(id),
  context_profile TEXT,                -- surcharge éventuelle
  UNIQUE (file_id, table_idx, slot_idx)
);

CREATE TABLE translation (
  id            BIGSERIAL PRIMARY KEY,
  source_id     BIGINT REFERENCES source_string(id),
  locale        TEXT NOT NULL,         -- 'fr', 'en', ...
  text          TEXT NOT NULL,
  status        TEXT NOT NULL CHECK (status IN
                ('untranslated','draft','translated','reviewed','locked')),
  revision      INTEGER NOT NULL DEFAULT 1,
  author_id     UUID,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  budget_bytes  INTEGER,               -- mis en cache par mh_budget
  budget_px_max INTEGER,
  UNIQUE (source_id, locale)
);

CREATE TABLE translation_history (... copie de chaque révision ...);
CREATE TABLE glossary_term (id, locale, source_term, target_term, note, mandatory BOOLEAN);
CREATE TABLE comment (id, source_id, author_id, body, created_at, resolved BOOLEAN);
CREATE TABLE length_profile (id TEXT PRIMARY KEY, max_px INT, max_lines INT,
                             max_bytes INT, font_id TEXT);
CREATE TABLE build (id, iso_md5, tdb_revision, toolkit_version, profile,
                    status, report_json, created_at);
```

### 7.3 Identité stable d'une chaîne

La clé `(file_id, table_idx, slot_idx)` est complétée par `source_hash`. Si l'on importe une autre version du jeu (HD, révision), une chaîne dont le hash est identique hérite automatiquement de sa traduction, sinon elle est marquée `fuzzy` avec la traduction précédente en suggestion.

### 7.4 Collaboration

- API REST (CRUD, recherche, export) et WebSocket (présence, verrous doux, mises à jour en direct de la jauge de budget du fichier).
- Concurrence optimiste : chaque écriture envoie `revision` ; en cas de conflit, le client reçoit les deux versions et propose une fusion.
- Rôles : traducteur, relecteur, mainteneur de build. Seul un `reviewed` ou `locked` entre dans un build de release ; les builds nightly incluent `translated`.
- Budget partagé : comme les octets sont mutualisés par fichier (section 8), le serveur diffuse en temps réel la consommation du fichier pour éviter que deux traducteurs consomment la même marge.

### 7.5 Import et export

| Format | Sens | Usage |
|---|---|---|
| Dossier mhtools (`filelist.txt` + `string_table_N.txt`) | Import/export | Reprise de projets existants, interopérabilité |
| CSV/TSV | Import/export | Tableurs, relecture externe |
| XLIFF 2.0 / PO | Import/export | Outils de TAO (OmegaT, Weblate, Poedit) |
| JSON de patch | Export | Diffs publics sans texte source |

La reprise de traductions existantes (TeamMaverickOne, autres équipes) doit se faire avec l'accord de leurs auteurs et en les créditant.

### 7.6 Aides à la traduction

- Mémoire de traduction (correspondances exactes et approximatives par trigrammes PostgreSQL `pg_trgm`, ou FTS5 en SQLite).
- Glossaire obligatoire pour la terminologie (monstres, objets, compétences), dans l'esprit de l'harmonisation sur MH3U/MHGU de la v6.3 ([CDRomance](https://cdromance.org/psp/monster-hunter-portable-3rd-english-patched-2/)).
- Pré-traduction automatique optionnelle (LLM local ou cloud), toujours en statut `draft`, avec le contexte (fichier, table, chaînes voisines, glossaire) et la contrainte de budget dans la consigne.

---

## 8. Module `mh_budget` — contrôle de la longueur

C'est le module qui protège contre les débordements. Il évalue quatre niveaux de contrainte, du plus dur au plus souple.

### 8.1 Niveau 1 — emplacement dans DATA.BIN (bloquant)

Le patch réécrit en place, sans relocation (section 1.2). Donc :

```
taille_chiffrée_alignée(fichier_reconstruit) <= slot_bytes
```

avec `taille_alignée = ceil(taille / 2048) × 2048`. Tout dépassement bloque le build.

### 8.2 Niveau 2 — tampon mémoire à l'exécution (bloquant en mode strict)

Le jeu charge les fichiers dans des tampons dont la taille réelle n'est pas documentée. Un fichier qui tient dans son emplacement mais qui est plus gros que l'original peut écraser de la mémoire voisine sur PSP. Deux politiques :

- `strict` (par défaut, release) : `taille_reconstruite <= taille_originale` ;
- `slot` (expérimental) : `taille_reconstruite <= slot_bytes`, autorisé seulement pour les fichiers validés en jeu (liste blanche alimentée par la QA).

Cette prudence s'applique aussi au mode plugin (`mhp3patch.prx`), dont la stratégie d'allocation n'est pas documentée publiquement.

### 8.3 Calcul exact de la taille d'une table

```dart
int measureStringTableFile(StringTableFile f, Encoder enc) {
  var size = 8 + 4 * f.tables.length;                 // en-tête
  for (final t in f.tables.whereType<StringTable>()) {
    size += 4 * t.slots.length + 4;                   // offsets + 0xFFFFFFFF
    final emitted = <int>{};
    for (final s in t.slots) {
      final target = s.aliasOf ?? s.index;
      if (emitted.add(target)) {
        size += enc.byteLength(s.tokens) + 1;         // chaîne + \0
      }
    }
    size += 1;                                        // double \0 final
  }
  return size + f.endData.length;
}
```

Le calcul est incrémental : modifier une chaîne met à jour la somme en O(1). La valeur affichée au traducteur est la marge restante du fichier, pas seulement la longueur de sa chaîne.

### 8.4 Niveaux 3 et 4 — affichage (avertissements)

| Niveau | Contrainte | Source des données |
|---|---|---|
| 3. Largeur en pixels | Somme des avances de glyphes ≤ `max_px` du profil | Table de largeurs extraite de la police, ou calibrée à la main |
| 4. Lignes | Nombre de `{NL}` + retours automatiques ≤ `max_lines` | Profil de contexte |

Profils de contexte (exemples à calibrer en jeu) :

```yaml
profiles:
  item_name:        { max_px: 0, max_lines: 1 }   # valeurs mesurées dans PPSSPP
  item_description: { max_px: 0, max_lines: 3 }
  quest_title:      { max_px: 0, max_lines: 1 }
  dialogue:         { max_px: 0, max_lines: 3, paginated: true }
  menu_label:       { max_px: 0, max_lines: 1 }
```

Les valeurs `max_px` sont laissées à 0 car elles doivent être mesurées : on part du texte japonais d'origine (pleine chasse) et on vérifie le rendu de chaînes de test dans l'émulateur.

Attention au calcul : en UTF-8, un caractère japonais occupe 3 octets alors qu'un caractère latin non accentué en occupe 1, et un caractère accentué français en occupe 2. Une traduction française peut donc tenir en octets tout en débordant en pixels, et inversement. Les deux métriques sont nécessaires.

### 8.5 Stratégies quand le budget est dépassé

Par ordre de préférence, proposées par l'outil :

1. Abréviations issues du glossaire (`Grande Épée` → `G. Épée`) ;
2. reformulation assistée (suggestion contrainte par la marge restante) ;
3. déduplication : si deux slots ont la même traduction, les faire pointer vers la même chaîne (alias), uniquement pour les tables où le partage d'offsets a été validé en jeu ;
4. redistribution : récupérer la marge de chaînes inutilisées (contenus de débogage, doublons) après vérification ;
5. dernier recours, hors v1 : relocation vers un espace libre, qui demande de modifier la TOC, de rechiffrer au nouveau LBA et probablement de patcher l'exécutable.

### 8.6 Rapport de budget

Chaque build produit un rapport JSON et HTML :

```json
{
  "file_id": 2311,
  "orig_bytes": 48212,
  "rebuilt_bytes": 47990,
  "slot_bytes": 49152,
  "policy": "strict",
  "status": "ok",
  "warnings": [
    {"table": 3, "slot": 41, "kind": "px_overflow", "value": 212, "max": 196}
  ]
}
```

---

## 9. Pipeline de build et de réinjection

### 9.1 Étapes

```
1. Verify    : MD5 ISO == registre ; offset DATA.BIN ISO9660 == registre
2. Snapshot  : figer la révision de la base (tdb_revision)
3. Select    : fichiers ayant au moins une traduction éligible au profil
4. Encode    : modèle + traductions → binaire en clair (codec)
5. Budget    : niveaux 1 et 2 bloquants, 3 et 4 en rapport
6. Encrypt   : chiffrer au LBA d'origine
7. Pad       : compléter jusqu'à l'alignement secteur
8. Patch     : sérialiser MHP3RD_DATA.BIN
9. Apply     : selon la cible (voir 9.2)
10. Verify   : ré-extraire depuis l'artefact, décoder, comparer à la base
11. Report   : rapport de build + manifeste signé (hashes)
```

Le graphe est incrémental : un cache par fichier, indexé par `(hash binaire d'origine, hash des traductions, version du codec)`, évite de reconstruire les fichiers inchangés.

### 9.2 Cibles de sortie

| Cible | Contenu | Usage |
|---|---|---|
| `iso` | Copie de l'ISO avec les blocs réécrits à `databin_offset + offset` | Tests, usage personnel |
| `plugin` | `MHP3RD_DATA.BIN` pour un chargeur CFW de type `mhp3patch.prx` | PSP réelle sans modifier l'ISO, dans la lignée du patch TeamMaverickOne ([GameBrew](https://www.gamebrew.org/wiki/Monster_Hunter_Portable_3rd_Translation_Patch_PSP)) |
| `delta` | Patch xdelta3 ou BPS entre ISO d'origine et ISO patché | Distribution publique sans données du jeu |
| `patcher` | Exécutable Dart AOT autonome (Windows/macOS/Linux) intégrant le patch | Utilisateurs finaux |

Le patcher autonome reprend le comportement de [patch-iso.py](https://github.com/npdawson/mhp3-translation-tools/blob/main/patch-iso.py) : vérifier le MD5, copier l'ISO, appliquer les blocs. On y ajoute la vérification du résultat et le support des deux versions.

### 9.3 Écriture sur l'ISO

```dart
Future<void> applyPatch(IsoImage iso, PatchFile patch, DataBinIndex index) async {
  final base = iso.locate('PSP_GAME/USRDIR/DATA.BIN').byteOffset;
  // FileMode.append = lecture/écriture sans troncature ; setPosition reste effectif
  final raf = await File(iso.path).open(mode: FileMode.append);
  try {
    for (final b in patch.blocks) {
      final entry = index.byOffset(b.offset)
          ?? (throw PatchError('offset hors index: ${b.offset}'));
      if (b.data.length > entry.slotBytes) {
        throw BudgetError(entry.id, b.data.length, entry.slotBytes);
      }
      await raf.setPosition(base + b.offset);
      await raf.writeFrom(b.data);
    }
  } finally {
    await raf.close();
  }
}
```

---

## 10. Assurance qualité

### 10.1 Tests automatisés

| Test | Objectif |
|---|---|
| Round-trip global | Pour chaque fichier détecté : `encode(decode(f)) == f`, bit à bit |
| Round-trip chiffrement | `encrypt(decrypt(x, lba), lba) == x` |
| Fuzzing des codecs | Entrées corrompues : pas de crash, pas de lecture hors bornes |
| Tests de propriétés | `measure(model) == encode(model).length` pour des modèles générés |
| Linter de traduction | Tokens identiques, glossaire, espaces, ponctuation française (espaces insécables avant `: ; ! ?` si la police le permet) |
| Régression de build | Le rapport de budget d'une release ne régresse pas |

### 10.2 Tests en émulateur

- PPSSPP (y compris son exécutable headless) pour lancer l'ISO patché, avec des sauvegardes d'état positionnées sur les écrans clés (menus, boutique, forge, liste de quêtes, dialogues).
- Captures automatiques comparées par différence d'image pour repérer les débordements de cadres.
- Liste blanche des fichiers validés en jeu, utilisée par la politique `slot` (8.2).
- Validation finale sur PSP réelle avant chaque release, car l'émulateur est plus tolérant sur la mémoire.

### 10.3 CI

- Dépôt public : tests unitaires sur des fixtures synthétiques (fichiers générés, aucun contenu Capcom).
- Runner auto-hébergé privé (Mac mini ou NAS) qui détient l'ISO de l'utilisateur et exécute les tests de round-trip et les builds nightly.

---

## 11. Stack et organisation du code

Choix proposé : Dart de bout en bout, pour partager les codecs entre la CLI, l'application Flutter et le serveur.

```
mhp3-toolkit/                  (monorepo, melos)
├── packages/
│   ├── mh_binary/             ByteReader/Writer LE, alignement, hash
│   ├── mh_iso/                ISO 9660, registre de versions
│   ├── mh_databin/            chiffrement, TOC, index, PatchFile
│   ├── mh_formats/            codecs (string_table_a, quest, pac, gim, font)
│   ├── mh_budget/             mesure octets/pixels/lignes, profils
│   ├── mh_tdb/                schéma drift, repository, sync
│   └── mh_build/              pipeline, cache, rapports
├── apps/
│   ├── mh_cli/                dart compile exe → mhtk
│   ├── mh_studio/             Flutter desktop (macOS/Windows/Linux)
│   └── mh_patcher/            patcher autonome pour utilisateurs finaux
├── server/
│   ├── mh_server/             dart_frog ou Serverpod, REST + WebSocket
│   └── docker-compose.yml     server + PostgreSQL + sauvegardes
├── config/                    game_versions.yaml, control_codes.yaml, profiles.yaml
└── catalog/                   libellés de fichiers (sans données du jeu)
```

Notes :

- `mh_studio` : Riverpod pour l'état, éditeur avec jauge de budget du fichier en direct, aperçu du rendu avec la vraie police extraite, vue côte à côte source/cible/glossaire.
- Les modules dérivés de mhtools (chiffrement, codec A) sont isolés dans un paquet sous GPLv3 si leur code est porté ; le reste peut garder une licence au choix, sous réserve d'un avis sur la compatibilité de l'ensemble.
- Alternative : un cœur en Rust (via `flutter_rust_bridge`) si les performances du chiffrement de `DATA.BIN` en Dart posent problème. Le chiffrement étant par octet ou par bloc, Dart AOT avec `Uint8List` devrait suffire.

### Commandes CLI

```bash
mhtk init      --iso MHP3.iso --project ./fr
mhtk extract   --project ./fr                 # TOC + détection + import en base
mhtk export    --project ./fr --format xliff --locale fr
mhtk import    --project ./fr --from ./mhtools_dump --format mhtools
mhtk budget    --project ./fr --file 2311     # rapport détaillé
mhtk build     --project ./fr --target iso,plugin,delta --policy strict
mhtk verify    --project ./fr --artifact out/MHP3.fr.iso
```

---

## 12. Feuille de route

| Phase | Livrable | Critère de sortie |
|---|---|---|
| 0. Fondations | `mh_binary`, `mh_iso`, portage du chiffrement | Round-trip du chiffrement sur 100 % de `DATA.BIN` |
| 1. Texte | Codec `string_table_a` avec alias, import/export mhtools | Round-trip bit à bit de toutes les tables détectées |
| 2. Base locale | SQLite, CLI, budget niveaux 1 et 2 | Premier ISO patché avec quelques chaînes modifiées, qui démarre |
| 3. Studio | Flutter desktop, jauges, glossaire, mémoire de traduction | Traduction d'un fichier complet sans sortir de l'outil |
| 4. Affichage | Extraction de la police, budget niveaux 3 et 4, tests PPSSPP | Rapport de débordement en pixels fiable sur les menus |
| 5. Collaboratif | Serveur, sync, rôles, revue | Équipe de 3 personnes sur le même fichier sans conflit perdu |
| 6. Extensions | Quêtes, textures GIM, version HD | Build multi-version depuis une seule base |

---

## 13. Risques

| Risque | Impact | Atténuation |
|---|---|---|
| Format de table non séquentiel ou partagé | Round-trip faux, corruption | Codec qui conserve les offsets (6.2), test bloquant |
| Tampon d'exécution plus petit que l'emplacement | Plantage sur PSP | Politique `strict` par défaut, liste blanche testée |
| Codes de contrôle mal identifiés | Textes cassés, plantages | Corpus d'analyse, linter de tokens, tests en jeu |
| Police sans glyphes accentués | Accents illisibles en français | Vérifier la police tôt (phase 4) ; sinon patch de police (codec `font`/`gim`) |
| Divergence PSP / HD | Patch incompatible | Index et offsets par version, hash de source par chaîne |
| Aspects légaux | Retrait du projet | Aucun contenu Capcom publié, distribution par delta, base source privée |
