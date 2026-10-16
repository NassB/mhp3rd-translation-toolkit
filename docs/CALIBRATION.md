# Calibrage de l'affichage (T36)

But : mesurer ce que le jeu affiche réellement du texte latin (largeur des caractères, retours à la ligne, débordement des boîtes), pour fonder le budget en pixels et en lignes (phase 4). Aucune donnée du jeu n'est versionnée : l'ISO de calibrage reste dans `out/`.

## 1. Préparer l'ISO de calibrage

Projet **séparé** de ton projet de traduction (locale `calib`) :

```bash
dart run apps/mh_cli/bin/mhtk.dart init --iso local/MHP3.iso --project out/calib --locale calib
```

```bash
dart run apps/mh_cli/bin/mhtk.dart extract --project out/calib
```

```bash
dart run apps/mh_cli/bin/mhtk.dart calibrate --project out/calib --file 17,2813,2814,2815,2816,2817,2818,2819
```

```bash
dart run apps/mh_cli/bin/mhtk.dart build --project out/calib --out out/MHP3.calib2.iso
```

Chaque chaîne japonaise des 8 fichiers de texte est remplacée par une chaîne de test :

- une **étiquette** `[#numéro]` au début (par exemple `[#4521]`), où le numéro est l'identifiant unique de la chaîne dans le projet : `out/calib/CALIBRATION.md` donne pour chaque numéro le fichier (section), la table, le slot, le motif ;
- puis un **motif de mesure**, selon `numéro` modulo 8 :

| numéro mod 8 | motif | sert à |
|---|---|---|
| 0 | `ruler` : `012345678a012345678b…` | compter les caractères visibles (la lettre change toutes les 10 positions) |
| 1 | `i` | largeur d'un caractère étroit |
| 2 | `W` | largeur d'un caractère large |
| 3 | `M` | idem |
| 4 | alphabet | rendu normal, minuscules et majuscules |
| 5 | `éèêëàâùûôîïçÉÈÀÇ` | **présence des accents** |
| 6 | ponctuation `.,;:!?'"«»()-/%` | rendu de la ponctuation |
| 7 | `ab cd ef gh` | largeur des espaces |

Garanties : une chaîne de test n'est **jamais plus longue en octets** que l'original (le build reste dans son budget) ; les **sauts de ligne, codes `~Xnn` et marqueurs `%d`/`%s`** de l'original sont conservés à leur place, donc la mise en page du jeu reste celle d'origine ; une chaîne trop courte pour porter son étiquette reste en japonais.

Le détail (étiquette, table.slot, motif, octets, sauts de ligne) est dans `out/calib/CALIBRATION.md`.

## 2. Jouer et relever

Charge `out/MHP3.calib2.iso` dans PPSSPP (ne remplace pas ton ISO de traduction ; si PPSSPP a encore un ancien ISO de calibrage ouvert, ferme-le avant de reconstruire sous le même nom). Pour chaque écran où tu vois une étiquette `[#numéro]` :

1. **Étiquette** lue à l'écran, et motif correspondant (voir le tableau ou `CALIBRATION.md`).
2. **Caractères visibles** : avec un motif `ruler`, la dernière lettre et le dernier chiffre visibles ; avec `i`/`W`/`M`, combien tiennent sur une ligne.
3. **Coupure ou retour automatique** : le texte revient-il à la ligne tout seul ? où ?
4. **Débordement** : sort-il de la boîte, est-il coupé, chevauche-t-il autre chose ?
5. **Accents** (motif 5) : tous les caractères sont-ils affichés, ou certains manquent/sont remplacés ?
6. **Type d'écran** : menu, boutique, dialogue, liste de quêtes, nom d'objet…

Tu peux me donner ces relevés en vrac, par exemple : « `[#4521]` (ruler) dans le menu du village : visible jusqu'à `3c`, pas de retour à la ligne, coupé à droite ». Des captures d'écran aident, mais ne les publie pas (texte et visuels du jeu).

## 3. Suite

Les relevés alimentent `config/font_metrics.yaml` (largeur par caractère) et les profils de longueur par type d'écran (`config/profiles.yaml`), puis le budget en pixels et en lignes (T38 à T41). Si les accents ne s'affichent pas, c'est la question de T42 (translittération ou patch de police).

## 4. Relevés (2026-10-16, PPSSPP Gold 1.20.2, premiers écrans)

Deux écrans du menu « Character Creation » (fichier 17, première version de l'ISO de calibrage, étiquettes `[table.slot]`) :

- **Accents : tous affichés** (`éèêëàâùûôîïçÉÈÀÇ`) : le jeu a des glyphes pour les lettres accentuées latines. **T42 (accents / police) n'a pas lieu d'être.**
- **Ponctuation : tout s'affiche** (`.,;:!?'"«»()-/%` et l'espace), y compris les guillemets français.
- **Largeur** : l'écran est rendu à 2 × (480 × 272) ; mesures sur les captures : **≈ 7 px de la PSP par caractère** pour les lettres, les accents, la ponctuation, les crochets et l'espace (20 caractères ≈ 139 px, 46 caractères ≈ 316 px, 17 caractères avec espaces ≈ 117 px). Ces premiers relevés sont compatibles avec une **police à chasse fixe (7 px)** pour le texte latin ; à confirmer avec les motifs `i`, `W` et `M` avant de l'adopter.
- **Mise en page** : le texte du dialogue est **centré** ; les sauts de ligne de la source sont respectés ; une ligne de 46 caractères (≈ 322 px) tient dans une boîte de ≈ 450 px sans retour à la ligne automatique.
- **Couleur** : un code `~Cxx` colore bien le texte en orange (étiquette entre deux flèches de sélection).

Il manque encore : les motifs `i`/`W`/`M` (chasse fixe ou proportionnelle ?), la largeur maximale avant débordement ou retour à la ligne, et les autres types d'écran (menus, boutique, quêtes, noms d'objets).

## 5. Relevés de la seconde série (2026-10-16, ISO `calib2`, étiquettes `[#numéro]`)

Quatre captures (écran « Character Creation » : liste et dialogues ; village : liste de menu et fenêtre de message). Les pas ont été mesurés **sur les pixels des captures** (autocorrélation de la colonne d'encre, écran = 1,77 × la PSP) :

| contexte | pas mesuré | en pixels PSP |
|---|---|---|
| dialogue sombre et listes de « Character Creation » (alphabet, `i`, `W`, `M`, règle) | 12,3 px d'écran | **7** |
| liste de menu du village (`M`, `i`, `ab cd`) | 12,3 px d'écran | **7** |
| fenêtre de message du village (en bas) | 10,7 px d'écran | **6** |
| bandeau blanc de « Character Creation » (ligne de `i`) | 16 px d'écran | **9** |

- **Chasse fixe confirmée dans chaque contexte** : `i`, `m`, `w`, `W`, `M`, les chiffres, la ponctuation et l'espace ont le **même pas** (la ligne d'alphabet complet et la ligne de `i` du même dialogue donnent 7 px). La largeur d'un texte latin est donc **nombre de caractères × pas du contexte**.
- Le **pas dépend de l'élément d'interface** (6, 7 ou 9 px selon la fenêtre), pas du fichier : il faut un pas par type d'écran.
- **Débordement** : la fenêtre de message du village **ne coupe pas** le texte (une ligne de 39 caractères déborde de la boîte, ≈ 234 px de large) ; les listes de menu **coupent** au bord de la boîte ; les bandeaux de « Character Creation » **centrent** le texte, qui déborde alors des deux côtés (l'étiquette passe sous l'icône de gauche).
- Aucun **retour à la ligne automatique** observé : les lignes multiples correspondent aux sauts de ligne de la source.
