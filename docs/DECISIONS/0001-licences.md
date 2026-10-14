# 0001 — Licences des dépôts de référence

## Contexte

Trois dépôts de référence sont clonés dans `third_party/` (non versionné). Il faut décider ce qui peut être porté en Dart et sous quelle licence publier les paquets.

## Constat (fichiers LICENSE/COPYING et en-têtes de source vérifiés)

| Dépôt | Révision | Licence | Preuve | Portable ? | Licence cible du paquet |
|---|---|---|---|---|---|
| `mhtools` (codestation) | `d71d174` (2013-07-27) | GPLv3 ou ultérieure | `COPYING`, en-têtes `src/**/*.java` (« Copyright (C) 2008 Codestation ») | Oui, œuvre dérivée | GPLv3+ |
| `mhef` (svanheulen) | `8a5132f` (2018-06-07) | GPLv3 ou ultérieure | `COPYING`, en-tête de `mhef/psp.py` (« Copyright 2013-2015 Seth VanHeulen »), `setup.py` | Oui, œuvre dérivée | GPLv3+ |
| `mhp3-translation-tools` (npdawson) | `889ff18` (2026-03-24) | GPLv3 (texte `LICENSE`) | `LICENSE` ; `patch-iso.py` sans en-tête individuel | Oui, œuvre dérivée | GPLv3 |

## Décision

1. Tout code porté ou traduit depuis l'un des trois dépôts va dans un fichier portant l'en-tête GPLv3, le copyright d'origine et la mention du fichier source (chemin + fonction).
2. Paquets concernés :
   - `mh_databin` (chiffrement, portage de `mhef/psp.py` `DataCipher`) : **GPLv3+**.
   - `mh_formats` (codec `string_table_a`, portage de mhtools) : **GPLv3+**.
   - `mh_iso` : constantes du registre (offsets, MD5) issues de `patch-iso.py`. Ce sont des faits, mais le parcours ISO 9660 est écrit à partir de la spécification, sans portage. Licence libre au choix tant qu'aucun code n'est copié.
3. Les paquets qui en dépendent (`mh_budget`, `mh_build`, `mh_tdb`, `apps/*`) sont liés à du code GPLv3 : l'application distribuée dans son ensemble doit l'être aussi (GPLv3+). Les paquets purement indépendants (`mh_binary`) peuvent rester sous licence permissive, mais leur usage dans un binaire GPL ne change rien pour l'utilisateur final.
4. Licence globale proposée du dépôt : **GPLv3+**, ce qui simplifie la conformité. À confirmer par l'humain.
5. Aucune donnée du jeu n'est concernée par ces licences (voir AGENTS.md §4.2).

## Alternatives

- Réécriture « propre » (clean-room) du chiffrement à partir d'une spécification pour pouvoir choisir une licence permissive : coût élevé, aucun bénéfice nécessaire pour un outil communautaire.
- Isoler le code GPL dans un seul paquet : possible mais le gain est nul tant que l'application finale le lie.

## Questions ouvertes

- `mhp3-translation-tools` : confirmer qu'aucun fichier ne porte une licence différente (pas d'en-tête individuel relevé).
- Valider la licence globale GPLv3+ avant le premier portage (T6).
