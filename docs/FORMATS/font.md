# Police du jeu — pas de police dans l'ISO (T37)

Statut : exploration **vérifiée sur l'ISO réelle** (ULJM05800, lecture seule), 2026-10-16. Aucune structure binaire de police n'est documentée ici : il n'y en a pas à décoder.

## Résultat

**Le jeu n'embarque pas ses glyphes.** Il affiche le texte avec la police système de la PSP, par la bibliothèque `sceFont` (polices `jpn0.pgf` / `ltn*.pgf` de `flash0:/font`, absentes de l'ISO).

## Ce qui a été trouvé

- **Appels `sceFont`** : le fichier 98 de `DATA.BIN` (conteneur `MWo3`, 378 880 octets) contient les chaînes d'erreur et de trace `Error (sceFontNewLib)`, `FindOptimumFont`, `Open`, `GetCharInfo`, `GetCharGlyphImage_Clip`, `Close`, `DoneLib` ; les fichiers 18 et 20 (modules `~SCE` en clair) contiennent `sceFont_Library`. Ce sont les seuls fichiers avec `sceFont`.
- **Aucun atlas de glyphes** : 11 conteneurs TMH (fichiers 1866, 1867, 3988, 3990 à 3997) = 54 GIM au format mhtools, plus 2 GIM standards `MIG.00.1PSP` (fichiers 22 et 23, 256×256 et 480×296 en INDEX_8, structure de chunks différente de `Gim.java`). Les 49 images décodables sont des icônes (équipements, monstres), des sprites, des ornements et des textures décoratives ; le fichier 22 est une feuille de boutons et de curseurs d'interface, le 23 l'écran de chargement. Aucune ne ressemble à une grille de caractères.
- **Aucune signature de police ailleurs** : pas de `PGF0` en tête de fichier, pas de `cmap`, `glyph` ni `flash0:/font`.
- **`EBOOT.BIN`** : il commence par `~PSP` (chiffré) : son contenu n'a pas pu être examiné ; `BOOT.BIN` commence par des zéros ; `SYSDIR` ne contient que `BOOT.BIN`, `EBOOT.BIN`, `OPNSSMP.BIN` et `UPDATE/` ; `USRDIR` ne contient que `DATA.BIN`.

## Conséquences

- Il n'y a **pas de table de largeurs à extraire** ni de police à patcher dans l'ISO : l'hypothèse « police sans glyphes accentués » (ARCHITECTURE §13) est écartée par l'observation en jeu (docs/CALIBRATION.md §4 : tous les accents s'affichent).
- Les largeurs viennent du rendu de `sceFont` et de la mise en page du jeu. **Mesurées dans PPSSPP** : police latine à chasse fixe, pas de 6, 7 ou 9 px selon l'élément d'interface (docs/CALIBRATION.md §5). Sur une vraie PSP, la police système est celle de la console (PPSSPP émule `flash0` avec ses propres polices) : à **vérifier sur console** avant de considérer les limites comme définitives (T43/T45).
- Le repli prévu par ARCHITECTURE §8.4 (métriques calibrées à la main, `config/font_metrics.yaml`) est la voie retenue ; l'aperçu de l'éditeur (T41) ne peut pas utiliser les vrais glyphes du jeu.

## Non vérifié

- Le contenu de `EBOOT.BIN` (chiffré) : pour trancher définitivement qu'il ne contient pas de police embarquée, il faudrait le déchiffrer (hors périmètre actuel).
- Les fichiers 1 à 6 (2 590 720 octets chacun), qui ressemblent à du bruit après déchiffrement (audio ou données compressées probablement) : non examinés.

## Reproduire

Scripts en lecture seule (sorties dans `local/explore/`, ignoré par git), depuis la racine du dépôt :

```bash
dart run packages/mh_databin/tool/explore_font.dart local/MHP3.iso
```

Les scripts `explore_font_magic.dart`, `explore_font_ids.dart`, `explore_gim22.dart` et `explore_gimdump.dart` du même dossier prennent les mêmes arguments (plus des identifiants de fichiers pour les trois derniers).
