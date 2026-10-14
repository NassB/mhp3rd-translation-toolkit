---
name: check
description: Vérifie format, analyse statique et tests d'un paquet ou du dépôt avec une sortie réduite aux erreurs. À utiliser après chaque modification de code au lieu de lancer les commandes à la main.
argument-hint: "[chemin du paquet, ex. packages/mh_formats] [--integration]"
allowed-tools: Bash(scripts/check.sh:*)
---

# Vérification compacte

Lancer :

```bash
scripts/check.sh $ARGUMENTS
```

Le script n'affiche que les erreurs et un résumé final (`OK` ou `FAIL`). Ne pas relancer les outils séparément pour obtenir plus de détails, sauf pour un test précis qui échoue : dans ce cas, `dart test <fichier> --name "<test>"` uniquement.

En cas d'échec :
1. corriger la cause, pas le test ;
2. ne jamais ajouter `skip`, assouplir une assertion ou ignorer un lint pour faire passer ;
3. après 2 échecs identiques, s'arrêter et résumer le diagnostic.
