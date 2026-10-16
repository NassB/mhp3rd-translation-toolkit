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
dart run apps/mh_cli/bin/mhtk.dart build --project out/calib --out out/MHP3.calib.iso
```

Chaque chaîne japonaise des 8 fichiers de texte est remplacée par une chaîne de test :

- une **étiquette** `[table.slot]` au début (par exemple `[0.12]`), pour savoir de quelle chaîne il s'agit à l'écran ;
- puis un **motif de mesure**, selon `slot` modulo 8 :

| slot mod 8 | motif | sert à |
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

Le détail (étiquette, motif, octets, sauts de ligne) est dans `out/calib/CALIBRATION.md`.

## 2. Jouer et relever

Charge `out/MHP3.calib.iso` dans PPSSPP (ne remplace pas ton ISO de traduction). Pour chaque écran où tu vois une étiquette `[t.s]` :

1. **Étiquette** lue à l'écran, et motif correspondant (voir le tableau ou `CALIBRATION.md`).
2. **Caractères visibles** : avec un motif `ruler`, la dernière lettre et le dernier chiffre visibles ; avec `i`/`W`/`M`, combien tiennent sur une ligne.
3. **Coupure ou retour automatique** : le texte revient-il à la ligne tout seul ? où ?
4. **Débordement** : sort-il de la boîte, est-il coupé, chevauche-t-il autre chose ?
5. **Accents** (motif 5) : tous les caractères sont-ils affichés, ou certains manquent/sont remplacés ?
6. **Type d'écran** : menu, boutique, dialogue, liste de quêtes, nom d'objet…

Tu peux me donner ces relevés en vrac, par exemple : « `[0.12]` (ruler) dans le menu du village : visible jusqu'à `3c`, pas de retour à la ligne, coupé à droite ». Des captures d'écran aident, mais ne les publie pas (texte et visuels du jeu).

## 3. Suite

Les relevés alimentent `config/font_metrics.yaml` (largeur par caractère) et les profils de longueur par type d'écran (`config/profiles.yaml`), puis le budget en pixels et en lignes (T38 à T41). Si les accents ne s'affichent pas, c'est la question de T42 (translittération ou patch de police).
