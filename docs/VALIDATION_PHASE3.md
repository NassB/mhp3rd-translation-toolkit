# Guide de validation de la phase 3 (T35)

Ce guide permet de valider le critère de sortie de la phase 3 :
**traduire un fichier complet sans sortir du studio, construire l'ISO, vérifier qu'il démarre.**

Statut : **rédigé le 2026-10-15, jamais exécuté de bout en bout.** Le studio n'a pas pu être lancé en fenêtre (Visual Studio absent sur le poste de développement) : seuls les tests de widgets, les tests du cœur et des essais sur l'ISO réelle en ligne de commande ont été faits. Les étapes 2 et 3 sont donc les premières exécutions réelles de l'interface ; toute différence avec ce texte est une information utile à reporter (voir §10).

Aucune donnée du jeu ne doit sortir de la machine (AGENTS.md §4.2) : ne publie ni capture d'écran du texte, ni dump, ni ISO.

---

## 0. Ce qui est validé, et ce qui ne l'est pas

| Dans le critère | Hors critère (phase 4) |
|---|---|
| Ouvrir le projet, voir les 8 fichiers et leurs jauges | Aperçu avec la vraie police du jeu |
| Traduire **toutes** les chaînes d'un petit fichier | Largeur en pixels, nombre de lignes à l'écran |
| Jauge d'octets, glossaire, mémoire, linter | Que le texte latin (accents compris) s'affiche correctement en jeu |
| Build `ok` + ISO écrit et relu | Cibles `plugin`, `delta`, `patcher` |
| L'ISO démarre dans PPSSPP | |

Point d'attention : la police du jeu est prévue pour le japonais. Du texte latin peut s'afficher vide, tronqué ou corrompu : **ce n'est pas un échec de la phase 3**, c'est l'objet de la phase 4. Note ce que tu vois, sans conclure.

---

## 1. Prérequis

### 1.1 Visual Studio (nécessaire pour lancer le studio sous Windows)

`flutter doctor` signale : `Visual Studio not installed; this is necessary to develop Windows apps`.

1. Télécharger **Visual Studio Community** (2022 ou plus récent) : <https://visualstudio.microsoft.com/downloads/>. Ne pas confondre avec *Visual Studio Code*.
2. Dans l'installateur, cocher la charge de travail **« Développement Desktop en C++ »** (*Desktop development with C++*), avec ses composants par défaut.
3. Installer, puis redémarrer le terminal.
4. Vérifier :

```bash
flutter doctor
```

Résultat attendu : la ligne `Visual Studio - develop Windows apps` passe en `[√]`. Les lignes Android et Chrome sont sans importance ici.

Si Flutter se plaint de liens symboliques (*symlink support*), activer le **mode développeur** de Windows (Paramètres → Système → Pour les développeurs).

### 1.2 Outils du dépôt

Le PATH doit contenir le SDK Flutter installé par FVM (Flutter 3.47.6, Dart 3.13.5) :

```bash
export PATH="$HOME/fvm/versions/stable/bin:$PATH"
```

Vérifier :

```bash
flutter --version
```

### 1.3 Données locales

- `local/MHP3.iso` : l'ISO ULJM05800 (déjà en place).
- `config/game_versions.yaml` : registre des versions (versionné).

Espace disque : **un build écrit une copie de l'ISO (~1,2 Go)** dans `out/`. Prévoir 2 à 3 Go libres.

---

## 2. Préparer un projet vierge

Tout se fait **depuis la racine du dépôt**. Le projet de validation est distinct de `out/t22a_project` (qui contient déjà une traduction de démonstration du fichier 17) pour partir d'un état connu.

Créer le projet (vérifie le MD5 de l'ISO et l'offset de `DATA.BIN`) :

```bash
dart run apps/mh_cli/bin/mhtk.dart init --iso local/MHP3.iso --project out/fr
```

Importer les tables de texte dans la base :

```bash
dart run apps/mh_cli/bin/mhtk.dart extract --project out/fr
```

Attendu : `detected: 8 string_table_a`, `imported: 8`.

Vérifier :

```bash
dart run apps/mh_cli/bin/mhtk.dart status --project out/fr
```

Attendu : `files: 8`, `strings: 15051`, toutes les traductions à 0.

---

## 3. Lancer le studio

Le studio cherche `config/game_versions.yaml` et `config/validated_files.yaml` **relativement au dossier de travail** (limite connue, voir §9). Il faut donc lancer l'exécutable **depuis la racine du dépôt**.

Compiler (première fois : plusieurs minutes) :

```bash
cd apps/mh_studio && flutter build windows --debug
```

Revenir à la racine puis lancer :

```bash
./apps/mh_studio/build/windows/x64/runner/Debug/mh_studio.exe
```

> Le chemin exact peut varier selon la version de Flutter ; le dossier `build/windows/` contient l'exécutable. `flutter run -d windows` peut lancer l’application avec un autre dossier de travail (non vérifié) ; dans ce cas les jauges et le build échoueraient avec « registre introuvable ».

### Contrôles à la première ouverture

1. La fenêtre « MHP3rd Studio » s'ouvre en thème sombre, avec « Ouvrir un projet ».
2. Saisir le **chemin complet** du dossier projet (ex. `D:\PROGRAMMATION\FlutterApps\mhp3rd-translation-toolkit\out\fr`) puis **Ouvrir**.
3. La liste affiche **8 fichiers** (`#17`, `#2813` … `#2819`), chacun « 0 / N traduites ».
4. Les jauges affichent d'abord « Jauge : calcul en cours… » puis, après **environ 15 secondes**, une barre verte « `… / … o · marge 0 o · strict` » par fichier.

À noter si ce n'est pas le cas : message de la bannière « Jauges indisponibles : … » (le texte de l'erreur dit ce qui manque).

---

## 4. Choisir le fichier

Taille et nombre de chaînes mesurés sur l'ISO réelle :

| Fichier | Taille | Chaînes |
|---|---|---|
| **#2819** | 10 240 o | **101** ← recommandé |
| #2813 | 16 384 o | 164 |
| #2814 | 14 336 o | 312 |
| #2818 | 45 056 o | 573 |
| #2815 | 155 648 o | 559 |
| #2817 | 391 168 o | 1 332 |
| #2816 | 145 408 o | 2 870 |
| #17 | 471 040 o | 9 140 |

Le contenu des fichiers n'est pas catalogué. Si le texte ne t'inspire pas, #2813 convient aussi ; éviter #17 pour cette validation (9 140 chaînes).

---

## 5. Scénario de traduction

Les durées entre parenthèses sont indicatives.

### 5.1 Préparer le glossaire (5 min)

1. Page projet → **Glossaire** → **Ajouter un terme**.
2. Saisir un terme source rencontré dans le fichier, sa traduction, cocher **Obligatoire** → **Enregistrer**.
3. Contrôles : le terme apparaît, avec la pastille « ! » des termes obligatoires. Tenter d'ajouter deux fois le même terme source doit afficher « glossary term already exists ».
4. Retour à la page projet.

### 5.2 Ouvrir le fichier et traduire (le gros du travail)

1. Dans la liste, **toucher la ligne** du fichier choisi : l'éditeur s'ouvre (« Fichier #2819 »). La jauge du fichier est en haut.
2. Colonne de gauche : les chaînes (table.slot, aperçu, statut). Un point apparaît à droite d'une chaîne modifiée non enregistrée.
3. Sélectionner une chaîne. À droite : la **source** (les sauts de ligne sont des pastilles ↵), le **champ de traduction**, les pastilles de glossaire éventuelles, la mémoire de traduction, le menu de **statut**, **Enregistrer** et **Annuler**.
4. Taper la traduction. Contrôles pendant la saisie :
   - la jauge du haut bouge **au bout de ~150 ms** et reste cohérente (tout passe en octets UTF-8 : un caractère accentué compte 2 octets) ;
   - une **pastille de glossaire** insère sa traduction à la position du curseur ;
   - le **linter** signale : nombre de sauts de ligne différent de la source (erreur), terme obligatoire absent (avertissement), espace de début/fin différente. Chaque chaîne de la source qui contient `↵` doit avoir autant de retours à la ligne dans la traduction (touche Entrée).
5. Choisir le statut **`translated`** dans le menu (c'est le niveau pris par le build « nightly ») puis **Enregistrer**. Le point « modifié » disparaît et le statut apparaît dans la liste.
6. Répéter pour **toutes les chaînes non-alias** du fichier. Les lignes marquées « alias du slot N » sont en lecture seule : elles reprennent la chaîne cible.

Conseils : japonais → français raccourcit presque toujours en octets (3 octets par caractère japonais contre ~1 en français), donc la jauge reste verte. Si elle passe à l'ambre (« slot seulement ») ou au rouge (« dépassé »), raccourcir la chaîne : le build refuserait.

### 5.3 Contrôles fonctionnels à faire au passage (≈ 10 min)

À faire une fois, sur des chaînes quelconques :

| Contrôle | Attendu |
|---|---|
| Écrire une traduction sans le terme obligatoire du glossaire | Avertissement « Terme obligatoire absent : … » |
| Écrire une traduction avec un saut de ligne en moins | Erreur « Nombre de sauts de ligne différent … » |
| Enregistrer une chaîne identique à une source déjà traduite ailleurs | La mémoire propose la correspondance « 100 % · exacte » après enregistrement de l'autre |
| **Annuler** après une saisie | Le champ revient au texte enregistré |
| Fermer l'éditeur (retour) et rouvrir le fichier | Les traductions sont conservées |
| Retour à la liste | La barre « n / N traduites » et la jauge ont changé |
| Éditer et enregistrer jusqu'à la dernière chaîne | La liste affiche « N / N traduites » |

### 5.4 Échange mhtools (optionnel, 5 min)

Dans l'éditeur, l'icône **Exporter** (flèche vers le haut) : saisir un dossier **inexistant ou vide** hors du dépôt versionné, par ex. `out/export-2819` → message « Dump écrit (N table(s)). ». Puis l'icône **Importer** sur le même dossier : « Aucune traduction nouvelle ou modifiée. » (l'export réimporté ne change rien).

---

## 6. Construire l'ISO

1. Page projet → **Build**.
2. Laisser les valeurs par défaut : ISO de sortie `out/MHP3.fr.iso`, profil `nightly`, statut minimal `translated`, politique `strict`.
3. **Lancer le build**. Une barre de progression apparaît (~20 s : MD5 de l'ISO, lecture de `DATA.BIN`, écriture de la copie, relecture). L'interface reste réactive.
4. Résultat attendu dans le cadre du rapport :
   - **« ISO écrit et vérifié »**, `Build #1 · révision N` ;
   - une ligne `Fichier 2819 : ok (… / … o, emplacement … o)` ;
   - aucune ligne « Vérification : … ».
5. Le build apparaît dans l'**historique** (`#1 · ok`).
6. Vérifier que `out/MHP3.fr.iso` existe et pèse **1 207 140 352 octets**, comme `local/MHP3.iso`.

Si le statut est « Budget dépassé » : le rapport indique le fichier ; retourner dans l'éditeur, raccourcir, puis relancer (aucun ISO n'est écrit dans ce cas).

> Le build refuse d'écraser un fichier existant. Pour relancer, changer le nom de sortie (`out/MHP3.fr.2.iso`) ou supprimer l'ancien fichier.

---

## 7. Test dans PPSSPP

1. Charger `out/MHP3.fr.iso` dans PPSSPP.
2. Observer et noter (sans capture publique) :
   - le jeu **démarre-t-il** jusqu'au menu principal ? plante-t-il, écran noir ?
   - que montrent les écrans où le texte du fichier modifié devrait apparaître (l'écran concerné n'est pas catalogué : si tu le trouves, note son emplacement) ?
   - texte lisible, caractères manquants, caractères corrompus, texte absent ?
3. **Test témoin conseillé** : l'erreur `80110309` (sauvegarde) vue lors de la phase 2 n'a jamais été comparée à l'ISO d'origine. Refaire le même geste (création de personnage) avec `local/MHP3.iso` **non modifié** dans le même PPSSPP :
   - même erreur → elle est indépendante du patch ;
   - pas d'erreur avec l'original → l'ISO construit est en cause, à signaler.

---

## 8. Critères de réussite

| # | Critère | Réussi si |
|---|---|---|
| 1 | Le studio se lance (Windows) | La fenêtre s'ouvre et le projet s'ouvre |
| 2 | Liste et jauges | 8 fichiers, jauges calculées |
| 3 | Fichier complet traduit **dans l'outil** | Tout le fichier à « N / N traduites » sans quitter le studio |
| 4 | Build | Statut « ISO écrit et vérifié », ISO de la bonne taille |
| 5 | Source intacte | `local/MHP3.iso` inchangé (jamais ouvert en écriture ; vérifiable par sa date de modification) |
| 6 | **ISO qui démarre** | Le jeu atteint le menu principal |

**La phase 3 est validée si les critères 1 à 6 sont remplis.** Le rendu du texte latin en jeu n'en fait pas partie.

---

## 9. Limites connues (à ne pas signaler comme bugs)

- Dossiers saisis à la main (pas de sélecteur : `file_picker` reporté).
- Registre des versions et `validated_files.yaml` cherchés relativement au dossier de travail (lancer depuis la racine, §3).
- Le saut de ligne se tape avec Entrée dans le champ ; les pastilles ↵ ne sont non éditables que dans les aperçus.
- Pas de garde « brouillon non enregistré » à la sortie, pas de Ctrl+S.
- Le linter n'empêche pas l'enregistrement.
- Pas d'annulation d'un build en cours.
- Les jauges de la liste ne se recalculent entièrement qu'à la réouverture du projet (elles sont mises à jour localement après un enregistrement).
- Après « Recharger » suite à un conflit, le budget enregistré ignore la version distante jusqu'au prochain calcul global.
- Cibles `plugin` et `delta` absentes.

---

## 10. Quoi me rapporter

Pour clore T35 dans `docs/PROGRESS.md`, indique :

1. Pour chaque critère 1 à 6 : réussi / échoué.
2. Les écarts avec ce guide (écran, libellé, durée), même mineurs.
3. Toute erreur affichée (copie du message, **sans texte du jeu**).
4. Le temps passé à traduire le fichier et ton ressenti sur l'éditeur (ce qui gêne, ce qui manque).
5. Le résultat du test témoin (§7.3) et ce que montre l'écran du fichier traduit en jeu.

Diagnostics rapides :

| Symptôme | Cause probable |
|---|---|
| `Jauges indisponibles : … registre …` | Studio lancé hors de la racine du dépôt (§3) |
| `Cannot find file … game_versions.yaml` au build | Idem |
| `ISO … MD5` inconnu | `local/MHP3.iso` n'est pas l'ISO enregistrée (`docs/DECISIONS/0002`) |
| Build « Rien à construire » | Aucune chaîne au statut `translated` ou plus (profil nightly) : vérifier les statuts |
| Build « Budget dépassé » | Une chaîne trop longue : voir le rapport, raccourcir |
| `clone target already exists` | Le fichier de sortie existe déjà : changer le nom |
