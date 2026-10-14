# 0002 — MD5 de référence pour ULJM05800

## Contexte

Le dump ISO de l'humain a un MD5 (`40ee8e114527e3355bcef3318ee00b66`) différent de celui de `patch-iso.py` (`8e19a966356a83b8b395957671494bd8`). Vérifications faites (lecture seule) : `DISC_ID` du `PARAM.SFO` = `ULJM05800`, taille 1 207 140 352 octets, `DATA.BIN` à l'offset 0x6D50000. Le round-trip du chiffrement a été validé sur ce dump (test `integration`, 2026-10-15).

## Décision

Le registre `config/game_versions.yaml` ne contient que ce dump vérifié. Le MD5 de `patch-iso.py` et l'entrée `NPJB40001_HD` (jamais vus ni testés ici) en sont retirés ; la version HD sera ajoutée en phase 6 avec un vrai dump. La vérification de l'offset par parcours ISO 9660 (AGENTS.md §4.3) reste appliquée.

## Alternatives

Garder les MD5 de `patch-iso.py` comme entrées « non vérifiées » : rejeté, cela accepterait des ISO jamais testées.

## Limite

La cause de la différence de MD5 avec `patch-iso.py` n'est pas identifiée. `docs/ARCHITECTURE.md` §4 liste encore les anciennes entrées ; à aligner sur demande explicite.
