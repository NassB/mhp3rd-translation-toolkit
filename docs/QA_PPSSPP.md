# QA en jeu avec PPSSPP (T43)

But : confronter ce que l'outil **prédit** (largeur en pixels, nombre de lignes, budget d'octets) à ce que le jeu **affiche réellement**, puis décider quand une limite ou une politique (`slot`) est assez sûre pour être utilisée. Rien dans ce document n'est un résultat : les tableaux sont à remplir au fil des essais. Aucune capture ni texte du jeu n'est versionné.

## 1. Principes

- **Prédit** = ce que calcule l'outil : `evaluateDisplay` (largeur = caractères × pas du contexte, lignes = sauts de ligne + 1, `config/font_metrics.yaml` et `config/profiles.yaml`) et le budget d'octets (`mhtk budget`).
- **Observé** = ce que PPSSPP affiche avec l'ISO de test. Une limite n'entre dans `config/profiles.yaml` qu'**après** avoir été mesurée ici ; une valeur à 0 veut dire « non mesuré » et ne déclenche aucun avertissement.
- Les mesures viennent de PPSSPP, qui émule la police système de la PSP (docs/FORMATS/font.md) : avant de figer une limite, **la confirmer sur une vraie PSP** si possible (§7).
- Les ISO de test sont des **copies** dans `out/` ; l'ISO d'origine n'est jamais modifié.

## 2. Environnement à noter à chaque série d'essais

| Élément | Valeur |
|---|---|
| Version de PPSSPP | Gold 1.20.2 (relevée sur les captures du 2026-10-16) |
| Système et carte graphique | à noter |
| Résolution de rendu | ×2 mesuré (fenêtre ≈ 960 px pour 480 px PSP) ; noter le facteur réel |
| ISO d'origine | `local/MHP3.iso` (MD5 de référence du registre) |
| ISO de test | nom et date du build (`out/…iso`), révision de la base (`tdb_revision` du rapport de build) |
| Langue du jeu / de la console émulée | à noter |

**Conversion d'une capture en pixels PSP** : `px_PSP = px_écran × 480 / largeur_de_la_zone_de_jeu_en_pixels_d'écran`. Avec un rendu ×2, diviser par 2. Les pas mesurés par l'autocorrélation d'une capture (docs/CALIBRATION.md §5) se calculent sans compter les caractères un par un.

## 3. États de sauvegarde et écrans

Créer, avec l'ISO de test chargé, **un état de sauvegarde par écran clé** (les textes sont lus au chargement de la zone : refaire l'état si l'ISO change). Écrans prioritaires demandés par l'humain (2026-10-16), puis les autres :

| # | Écran | Type de profil probable | État créé | Remarques |
|---|---|---|---|---|
| 1 | Menus (village, objets, options) | `menu_label` | | |
| 2 | Boutique (liste et descriptions) | `item_name`, `item_description` | | |
| 3 | Forge (listes d'équipements) | `item_name`, `item_description` | | |
| 4 | Liste de quêtes (titres) | `quest_title` | | |
| 5 | Fenêtres de message et dialogues | `dialogue` | | |
| 6 | Création de personnage (déjà observé : 7 px, 9 px) | `menu_label`, `dialogue` | | |

Les identifiants de profils ci-dessus sont des **hypothèses** (`config/profiles.yaml`) : l'association écran ↔ profil se fait au fil des mesures, avec `mhtk profile set` ou l'éditeur (T41).

## 4. Procédure pour un écran

1. Construire l'ISO de calibrage si ce n'est pas fait (docs/CALIBRATION.md) ; le rapport `out/calib/CALIBRATION.md` donne, pour chaque étiquette `[#numéro]`, le fichier, la table, le slot, le motif, les octets et le **nombre de caractères par ligne**.
2. Dans PPSSPP, aller à l'écran, **repérer les étiquettes** `[#numéro]` visibles et prendre une capture (garder en local).
3. Pour chaque étiquette notée, relever dans la grille (§5) : le contexte (écran), les caractères visibles par ligne, la largeur en pixels PSP (mesure sur capture), le nombre de lignes affichées, et ce qui se passe au bord (coupé, déborde, passe à la ligne, chevauche autre chose).
4. Lire les caractères visibles d'un motif `ruler` pour trouver la **limite de largeur** de l'élément : dernier caractère visible avant la coupure, ou position où le texte sort de la boîte.
5. Reporter dans `config/profiles.yaml` (`max_px`, `max_lines`, `font_context`) **uniquement** les valeurs lues, avec la date et l'écran en commentaire, puis refaire un build de test avec des traductions de longueurs connues (§5, colonnes « prédit »).

## 5. Grille prédit / observé

Une ligne par chaîne testée (copier dans un tableur ou ici). « Prédit » vient de l'outil, « observé » de PPSSPP ; l'écart se calcule en caractères (un caractère = un pas).

| Date | Étiquette / chaîne | Écran | Profil | Pas (px) | Car./ligne prédits | Largeur prédite (px) | Lignes prédites | Car./ligne observés | Largeur observée (px) | Lignes observées | Écart (car.) | Comportement au bord | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | | |

Colonnes de calcul : largeur prédite = caractères par ligne × pas ; lignes prédites = sauts de ligne + 1 ; écart = observé − prédit (en caractères). Verdict : **conforme** (écart nul, comportement attendu), **tolérable** (écart ≤ 1 caractère) ou **à corriger** (écart plus grand, ou comportement inattendu).

**Critère de fiabilité proposé** (à valider par l'humain avant T45) : le rapport de débordement est fiable pour un type d'écran si, sur au moins 20 chaînes variées de cet écran, l'écart est de **0 caractère** pour au moins 95 % d'entre elles et **jamais plus d'un caractère**, et si aucune chaîne signalée « conforme » ne déborde en jeu.

## 6. Liste blanche `config/validated_files.yaml` (politique `slot`)

La politique `slot` (taille reconstruite ≤ emplacement au lieu de ≤ taille originale) n'est autorisée que pour un fichier **testé en jeu**. Procédure :

1. Construire avec `--policy slot` une ISO où le fichier dépasse sa taille d'origine (sans dépasser l'emplacement) ; le rapport de build doit être `ok`.
2. Charger l'ISO dans PPSSPP et **parcourir tous les écrans** qui lisent ce fichier (états de sauvegarde, §3) ; aucune chaîne de ce fichier ne doit être tronquée, corrompue ou faire planter le jeu.
3. Seulement alors, ajouter l'identifiant du fichier à `config/validated_files.yaml` et le consigner ci-dessous.

| ID du fichier | Date | ISO testée | Écrans parcourus | Résultat | Ajouté à la liste |
|---|---|---|---|---|---|
| | | | | | |

La liste est **vide** tant qu'aucun test n'a été fait.

## 7. Vérification sur une vraie PSP

PPSSPP émule `flash0` avec ses propres polices : si une PSP et un moyen de lancer une ISO modifiée sont disponibles, **refaire sur console** au moins les mesures de pas (§4, étape 4) d'un écran de chaque type. Noter les écarts avec PPSSPP ici ; tant que ce n'est pas fait, les limites mesurées sont valables « sous PPSSPP ».

| Écran | Pas PPSSPP (px) | Pas PSP (px) | Date | Remarques |
|---|---|---|---|---|
| | | | | |

## 8. Test témoin de l'erreur `80110309`

Contexte : à la validation de la création du personnage, PPSSPP a affiché l'erreur `80110309` avec l'ISO patchée de la phase 2 (`out/demo.iso`). Elle a été jugée sans rapport avec le patch, mais **le test témoin n'a jamais été fait**.

Protocole :

1. Charger l'**ISO d'origine** (`local/MHP3.iso`), dans les mêmes réglages de PPSSPP (même version, même dossier de sauvegarde, état « première partie »).
2. Faire le même geste : créer un personnage et valider.
3. Recommencer avec une ISO de test (traductions) puis avec l'ISO de calibrage.
4. Consigner le résultat :

| ISO | Version PPSSPP | Erreur `80110309` | Remarques |
|---|---|---|---|
| Origine (`local/MHP3.iso`) | | à tester | |
| Traduction (`out/…`) | | | |
| Calibrage (`out/MHP3.calib2.iso`) | | | |

- Si l'erreur apparaît aussi avec l'ISO d'origine : elle vient de l'environnement (dossier de sauvegarde, disque, version de PPSSPP), pas du patch.
- Si elle n'apparaît qu'avec une ISO modifiée : la reprendre comme anomalie de build (comparer les octets modifiés, tester avec un seul fichier modifié, puis avec un seul slot raccourci).

## 9. Journal des essais

| Date | ISO / build | Écrans testés | Résultat | Suite |
|---|---|---|---|---|
| 2026-10-16 | `out/MHP3.calib.iso` puis `calib2` | création de personnage, village | accents et ponctuation affichés ; police à chasse fixe de 6, 7 ou 9 px selon l'élément (docs/CALIBRATION.md §4-5) | mesurer des limites par écran |
