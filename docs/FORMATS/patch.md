# Format `MHP3RD_DATA.BIN` (patch)

Statut : **vérifié sur le code de référence** (mhtools, patch-iso.py) ; pas encore confronté à un patch réel ni testé en jeu.

Sources : `third_party/mhtools/src/base/PatchBuilder.java` l.36-84 (`create`), `third_party/mhp3-translation-tools/patch-iso.py` l.17-30 (`Patch.__init__`) et l.45-66 (`patch_iso`).

Little-endian. Les offsets sont **relatifs au début de `DATA.BIN`** (`iso_offset + offset` à l'application), pas absolus.

| Offset       | Taille | Type | Champ                                      |
|--------------|--------|------|--------------------------------------------|
| 0x00         | 4      | u32  | `count`                                    |
| 0x04 + 8·i   | 4      | u32  | `offset[i]` (= `lba × 2048`)               |
| 0x08 + 8·i   | 4      | u32  | `length[i]` (multiple de 1024 exigé)       |
| 4 + 8·count  | 0..15  | 0x00 | padding jusqu'à un multiple de 16          |
| suite        | Σ len  | u8[] | blocs chiffrés concaténés, ordre de la table |

- En-tête : Python `headerlen = N*8 + 4`, `data_offset = headerlen + (-headerlen % 16)`. `8N+4` valant 4 ou 12 modulo 16, le padding fait toujours ≥ 4 octets : le terminateur `u32 0` que mhtools écrit à `4 + 8N` tombe dans le padding (même octets que le nôtre : zéros).
- mhtools écrit en plus une queue optionnelle `install_tables` (depuis `data_install.txt`) après les blocs ; `patch-iso.py` l'ignore. `PatchFile.parse` l'ignore, `serialize` ne l'écrit pas. Son sens (offsets d'installation) est inconnu.
- mhtools écrit `length = taille du slot` (données + remplissage de zéros jusqu'au slot suivant). Nous exigeons seulement `length % 2048 == 0` et `length <= slotBytes`.
- Implémentation : `packages/mh_databin/lib/src/patch_file.dart` (`PatchFile.serialize/parse/validate`).
