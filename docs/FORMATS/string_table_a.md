# Format `string_table_a` (codec A de mhtools)

**Statut : documenté depuis les sources de référence, NON vérifié sur fichiers réels.**
À confirmer en T13 (`/explore-data`). Fichiers concernés (commentaires mhtools) : `0016`, `0017`, `475x`, motif `(00[1-2][0-9]|47[0-9][0-9])`. Le fichier doit être déchiffré au préalable.

Sources :
- `third_party/mhtools/src/dec/ExtractPluginA.java:36-129` (`extract`)
- `third_party/mhtools/src/enc/RebuildPluginA.java:38-204` (`compile`)
- `third_party/mhtools/src/base/HelperDec.java:34-52` (`readString`)
- `third_party/mhp3-translation-tools/extractA.py:7-62`

Licences : mhtools et mhp3-translation-tools sont GPLv3 (voir `docs/DECISIONS/0001-licences.md`).

## Structure (little-endian, entiers 32 bits signés)

| Offset | Taille | Type | Champ | Remarque |
|---|---|---|---|---|
| 0x00 | 4 | i32 | `tablesCount` | nombre de tables principales (N) |
| 0x04 | 4 | i32 | `unknownHeader` | ignoré par l'extraction ; le rebuild écrit 8. **Conserver tel quel** |
| 0x08 | 4×N | i32[N] | `tableOffsets` | offset absolu ; `-1` (0xFFFFFFFF) = table nulle |
| `tableOffsets[j]` | 4×K | i32[K] | `stringOffsets` | K offsets de chaînes |
| … | 4 | i32 | sentinelle `-1` | fin de la table d'offsets |
| … | var | octets | K chaînes UTF-8 zéro-terminées | contiguës selon mhtools |
| … | 1 | u8 | `0x00` | octet de fin de table |
| fin | var | octets | `endData` | tout ce qui suit la dernière table, copié tel quel |

Offsets de chaînes : mhtools les ignore (seul K compte) et les recalcule (`4×K + 4` relatif au début de la table, puis cumul `len(UTF-8)+1`). Notre codec doit les **conserver** (alias possibles, AGENTS.md §4.5).

## Divergences et pièges des références

- Java `readString` avale tous les 0 qui suivent une chaîne : une chaîne vide au milieu d'une table fausse le comptage ; `endData` commence au premier octet non nul (bourrage de 0 perdu).
- Python `read_table` s'arrête à deux 0x00 consécutifs ; `endData` garde les 0 de bourrage.
- Table à K = 0 : le rebuild produit `-1` seul, ce qui ne restitue pas forcément les octets d'origine.
- Aucun alignement/padding entre tables ni chaînes dans le rebuild ; seulement le remplissage de fin jusqu'à la taille d'origine.
- Charset : UTF-8 (pas de Shift-JIS). Codes de contrôle non traités : octets bruts.

## Conséquences pour le codec (à trancher en T11)

- Décoder en s'appuyant sur les **offsets stockés** (pas sur le balayage de zéros) ; vérifier sur réel que les offsets sont bien contigus ou aliasés.
- Conserver `unknownHeader`, offsets de chaînes, octets de fin et `endData` pour le round-trip bit à bit.

## Questions ouvertes

- Sens de `unknownHeader` (0x04) et sens réel des offsets de chaînes dans les fichiers du jeu.
- `endData` commence-t-il par des 0 dans les fichiers réels ?
- Existence d'alias et de chaînes vides au milieu d'une table dans les fichiers réels.
- Signification des codes de contrôle (voir `config/control_codes.yaml`).
