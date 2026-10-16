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

## 10. Automatisation des captures : étude de faisabilité (T44, 2026-10-16)

**Verdict : semi-automatisable avec l'installation actuelle (PPSSPP Gold 1.20.2), sans `PPSSPPHeadless`.** Une visite scriptée (lancer l'ISO, envoyer des touches, capturer la fenêtre) fonctionne ; l'accès direct à un écran donné et la comparaison automatique d'images restent à construire.

| Brique | Résultat |
|---|---|
| `PPSSPPHeadless` | **Absent** du paquet Gold (`PPSSPPWindows.exe`, `PPSSPPWindows64.exe`, `assets/`). C'est l'exécutable de test de PPSSPP (compilé depuis les sources avec CMake, `-DHEADLESS=ON`). D'après son code source il accepte `--graphics=software\|vulkan`, `--timeout-wall=N`, `--root`, `--compare`, `--screenshot-save=FICHIER` (png/bmp), `--state=FICHIER` (charge un état), `--resolution-scale=N`. **Non essayé** (pas de binaire, pas de chaîne de compilation installée). Il n'y a pas d'arrêt après N images : seulement un délai en secondes, et il ne reçoit pas de touches : il ne conviendrait que **combiné à des états de sauvegarde** (§3). |
| Débogueur WebSocket de PPSSPP | **Fonctionne** : avec `RemoteDebuggerOnStartup = True` (section `[General]` de `ppsspp.ini`), PPSSPP écoute sur un port local **aléatoire** (49607, 62944… lu avec `Get-NetTCPConnection -State Listen -OwningProcess <pid>`), sous-protocole `debugger.ppsspp.org`, chemin `/debugger`. `game.status` répond (jeu chargé) ; `input.buttons.press` (`cross`, `start`…, durée en images) **fonctionne** : deux appuis ont fait passer la vidéo d'intro au titre. |
| Capture par le débogueur (`gpu.buffer.screenshot`) | **Échec** : « Could not download output », après `cpu.stepping`, avec le moteur graphique par défaut (D3D11) et un essai de `GraphicsBackend = 0` (non vérifié que le réglage ait été pris en compte). Piste non explorée : état d'arrêt du GPU (GE) ou moteur Vulkan. |
| Capture de la fenêtre (`PrintWindow`) | **Fonctionne**, même fenêtre cachée : image de la zone cliente en **960×544** (rendu ×2 = 2 × 480×272), couleurs correctes. Script : `apps/mh_cli/tool/ppsspp_window_capture.ps1`. `CopyFromScreen` est à éviter : il capture ce qui est devant la fenêtre. |
| Navigation | `apps/mh_cli/tool/ppsspp_capture.dart` (`--port`, `--press cross,start`, `--shots 0`) envoie les touches. Pour atteindre un écran précis il faut une **suite de touches** (attentes comprises) ou un état de sauvegarde ; le chargement d'un état depuis la ligne de commande de la version graphique **n'a pas été vérifié**. Un état contient les textes déjà chargés en mémoire : à refaire après chaque changement d'ISO. |
| Comparaison d'images | Non faite. Pour la grille (§5), une capture + une règle `ruler` suffisent à lire les caractères visibles ; l'autocorrélation utilisée en T36 (docs/CALIBRATION.md §5) donne le pas sans compter à la main. |

**Isolation utilisée pour l'essai** : une copie portable de PPSSPP dans `out/ppsspp_test/` (exécutable + `assets/`, sans `installed.txt`, donc ses propres réglages dans `memstick/`) avec `ppsspp.ini` : `[General] FirstRun = False`, `CheckForNewVersion = False`, `RemoteDebuggerOnStartup = True`, `[Sound] Enable = False`. L'installation et les réglages de l'humain (`D:\Documents\PPSSPP`) n'ont pas été touchés.

**Suite possible** (à demander) : un script de visite `ppsspp_tour.dart` (lancer, attendre, séquence de touches par écran clé, capture de fenêtre, rognage de la zone, mesure du pas par autocorrélation) alimentant la grille §5. Les captures et les images du jeu restent dans `out/`, jamais dans le dépôt.

### 10.1 Visite scriptée `ppsspp_tour` (2026-10-16)

`apps/mh_cli/tool/ppsspp_tour.dart` enchaîne ces briques : il lance PPSSPP (copie portable isolée, voir ci-dessus), lit le port du débogueur dans `netstat -ano`, attend le jeu, exécute un script JSON (`wait`, `press`, `shot`), capture la fenêtre (`ppsspp_window_capture.ps1`, passé en `-EncodedCommand` : la politique d'exécution de PowerShell, qui bloque les `.ps1`, n'est pas modifiée) et **mesure le pas de chaque ligne de texte** par autocorrélation (`apps/mh_cli/tool/ppsspp/image_analysis.dart`, PNG décodé sans dépendance, testé sur des images synthétiques). Rapport : `<sortie>/report.md`.

```bash
dart run apps/mh_cli/tool/ppsspp_tour.dart --exe out/ppsspp_test/PPSSPPWindows64.exe \
  --iso out/MHP3.calib2.iso --script apps/mh_cli/tool/tours/character_creation.json \
  --out out/ppsspp_tour
```

Étapes du script : `{"wait": 30}` ; `{"press": ["circle"], "hold": 45, "pause": 7}` ; `{"shot": "nom", "analyze": true}` (toutes les lignes) ou `"regions": [[x0,y0,x1,y1]]` ; `press` accepte `"until": {"region": [...], "lumMin": a, "lumMax": b}` et `"tries": N` : la touche est **répétée tant que la luminance moyenne de la zone n'est pas celle de l'écran attendu** (à utiliser parce que le jeu **ignore parfois une touche**, p. ex. les premières au titre).

**Constats de l'essai** (PPSSPP Gold 1.20.2, ISO `calib2`) :

- `start` n'est **pas** pris en compte au titre ; `circle` (maintenu 45 images) l'est, mais pas toujours du premier coup : d'où `until`. Chemin automatisé : titre → `circle` → GAME MENU → `circle` → Character Creation, en ≈ 1 min 30 depuis le lancement à froid (le chargement du jeu domine).
- **Mesure automatique sur Character Creation** : bandeau blanc **9,00 px** (PSP), bandes grises **7,00 px**, avec une confiance de 0,65 à 0,90 : **identique aux mesures manuelles de T36** (docs/CALIBRATION.md §5). Une bande « 5,00 px » à y = 128-144 est le décor du titre : les bandes de texte sont à repérer par leur pas plausible (6, 7 ou 9) et leur confiance.
- Limites : seuls les écrans atteignables **sans sauvegarde** sont couverts (titre, GAME MENU, Character Creation). Les écrans de la boutique, de la forge, des quêtes ou du village exigent un **fichier de sauvegarde** dans `memstick/PSP/SAVEDATA/` de la copie portable (celui de l'humain : **à copier par lui**, je ne l'ai pas touché) et une suite de touches propre à chaque écran. Les seuils de luminance sont des repères empiriques propres à ces trois écrans.
