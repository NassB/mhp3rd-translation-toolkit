# 0002 — Variante de MD5 pour ULJM05800

## Contexte

Le dump ISO de l'humain a un MD5 (`40ee8e114527e3355bcef3318ee00b66`) différent de la référence de `patch-iso.py` (`8e19a966356a83b8b395957671494bd8`). Vérifications faites (lecture seule) : `DISC_ID` du `PARAM.SFO` = `ULJM05800`, taille 1 207 140 352 octets (identique), `DATA.BIN` à l'offset 0x6D50000 (identique au registre).

## Décision

Ajouter une seconde entrée `ULJM05800` dans `config/game_versions.yaml` avec ce MD5. La vérification de l'offset par parcours ISO 9660 (AGENTS.md §4.3) reste appliquée.

## Alternatives

Chercher un dump au MD5 exact de la référence : plus long, sans garantie.

## Limite

La cause de la différence d'octets n'est pas identifiée (comparaison avec la référence impossible). Le round-trip de `DATA.BIN` reste à valider par le test `integration`.
