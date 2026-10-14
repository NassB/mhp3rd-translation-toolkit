# Prompts Claude Code — MHP3rd Translation Toolkit

## 0. Préparation (à faire toi-même, une fois)

```bash
mkdir mhp3-toolkit && cd mhp3-toolkit && git init
mkdir -p docs third_party local
# copier : AGENTS.md, CLAUDE.md, PROMPTS.md, .claude/, scripts/, docs/ARCHITECTURE.md, docs/PROGRESS.md
chmod +x scripts/check.sh
git clone https://github.com/codestation/mhtools third_party/mhtools
git clone https://github.com/svanheulen/mhef third_party/mhef
git clone https://github.com/npdawson/mhp3-translation-tools third_party/mhp3-translation-tools
cp /chemin/vers/ton/MHP3.iso local/MHP3.iso
export MHP3_ISO="$PWD/local/MHP3.iso"     # à mettre dans ton .zshrc ou un .envrc
```

Lancer Claude Code à la racine : `claude`.

---

## 1. Prompt de démarrage (première session uniquement)

À coller tel quel, en mode plan (Shift+Tab) :

```
Tu démarres le projet MHP3rd Translation Toolkit.

Contexte : lis CLAUDE.md et AGENTS.md (déjà chargés), puis seulement les sections 2, 3, 11 et 12 de docs/ARCHITECTURE.md (repère les lignes avec grep -n "^## ").

Objectif de cette session : préparer le terrain, sans encore implémenter de logique métier.

1. Vérifie l'environnement : version de Dart et Flutter, présence de third_party/mhtools, third_party/mhef, third_party/mhp3-translation-tools, variable MHP3_ISO. Signale ce qui manque, sans rien installer.
2. Vérifie les licences des trois dépôts third_party (fichiers LICENSE) et crée docs/DECISIONS/0001-licences.md : ce qu'on peut porter, sous quelle licence doit être chaque paquet.
3. Initialise le monorepo Dart (pub workspace à la racine, Melos uniquement si nécessaire) avec les paquets vides de AGENTS.md §3 : pubspec, analysis_options.yaml strict, dart_test.yaml avec les tags integration et slow, un test trivial par paquet.
4. Crée .gitignore conforme à AGENTS.md §11 et vérifie avec git check-ignore que local/, third_party/ et *.iso sont bien ignorés.
5. Crée config/game_versions.yaml d'après ARCHITECTURE.md §4.
6. Lance /check : tout doit être OK.
7. Découpe la phase 0 dans docs/PROGRESS.md en sous-tâches de taille "une session" (≤ ~300 lignes de code chacune), avec un critère vérifiable par sous-tâche.
8. Termine par /session-close.

Contraintes : pas de dépendance hors SDK sans me la proposer (sauf test, lints, path). Ne lis aucun binaire. Présente d'abord ton plan, puis attends mon accord.
```

---

## 2. Boucle de travail (toutes les sessions suivantes)

Une session = une tâche :

```
/clear
/phase-run
```

Variante pour cibler une tâche précise :

```
/phase-run portage DataCipher depuis third_party/mhef
```

À la fin de chaque session, lancer toi-même les commandes listées dans « À LANCER PAR TOI », puis :

- si OK : `git add -A && git commit -m "<commit proposé>"` ;
- si KO : colle uniquement la fin de la sortie (≤ 30 lignes) dans un nouveau `/phase-run corriger <résumé>`.

---

## 3. Points de contrôle humains (obligatoires)

| Moment | Ce que tu fais | Prompt ensuite |
|---|---|---|
| Fin phase 0 | `scripts/check.sh packages/mh_databin --integration` → round-trip chiffrement sur tout DATA.BIN | `Le critère de sortie de la phase 0 est validé (sortie : OK). Coche-le dans PROGRESS.md, passe à la phase 1 et découpe-la en sous-tâches. Puis /session-close.` |
| Phase 1, identification des tables | rien, l'agent utilise /explore-data | `/explore-data quels fichiers de DATA.BIN sont des tables de texte au format A ? Liste ID, taille, nombre de tables, nombre de chaînes.` |
| Fin phase 1 | round-trip bit à bit de toutes les tables en integration | idem phase 0 → phase 2 |
| Phase 2, premier ISO patché | lancer `out/*.iso` dans PPSSPP, vérifier que les chaînes modifiées s'affichent et que le jeu ne plante pas | `Test en jeu : <OK / plantage à tel écran / texte corrompu>. Mets à jour PROGRESS.md et docs/FORMATS si besoin.` |
| Phase 4, calibrage | mesurer les largeurs max dans PPSSPP pour chaque profil | `Mesures en jeu : item_name=<px>, item_description=<px>/<lignes>, ... Mets à jour config/profiles.yaml et les tests.` |
| Avant release | test sur PSP réelle (CFW + plugin, et ISO patché) | `Test PSP réelle : <résultat>.` |

---

## 4. Prompts utiles ponctuels

Revue de phase (en fin de phase, avant validation) :

```
Fais une revue de la phase en cours : relis AGENTS.md §4 et §9, puis vérifie sur le code de la phase uniquement : sources citées pour chaque structure binaire, champs inconnus conservés, measure == encode().length testé, aucun skip injustifié, aucune donnée du jeu versionnée. Liste les écarts (fichier:ligne), ne corrige rien.
```

Débogage d'un round-trip qui échoue :

```
/explore-data le round-trip du fichier <ID> échoue. Compare original et reconstruit : premier offset divergent, contexte xxd de 64 octets autour, structure attendue à cet offset d'après docs/FORMATS. Donne la cause probable.
```

Reprise après une longue pause :

```
Résume en 10 lignes l'état du projet d'après PROGRESS.md et git log --oneline -15, puis propose la prochaine tâche. Ne code rien.
```

---

## 5. Réglages pour économiser tokens et crédits

| Réglage | Recommandation |
|---|---|
| Modèle | Opus pour le prompt de démarrage, les revues de phase et le débogage de format ; Sonnet pour `/phase-run` courant (`/model sonnet`) |
| Effort | `medium` par défaut, `high` pour le portage du chiffrement et les codecs |
| `/clear` | Entre chaque tâche ; PROGRESS.md garde la mémoire |
| `/compact` | Seulement si une tâche est longue et doit continuer ; préférer la découper |
| Exploration | Toujours via `/ref-lookup` et `/explore-data` (sous-agents : leur lecture ne reste pas dans ton contexte principal) |
| Sorties | Toujours `/check` (sortie limitée aux erreurs) au lieu de `dart test` brut |
| Logs collés | 30 lignes max, la fin de la sortie |
| `/context` | Vérifier de temps en temps ce qui occupe le contexte |
| `/doctor` | Peut signaler des instructions permanentes trop longues à convertir en skills |
