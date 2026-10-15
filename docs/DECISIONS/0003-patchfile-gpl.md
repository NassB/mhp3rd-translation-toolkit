# 0003 — `PatchFile` : portage de mhtools / patch-iso.py

## Contexte
T17 implémente le format `MHP3RD_DATA.BIN` (docs/FORMATS/patch.md).

## Décision
- `patch_file.dart` porte la structure de `PatchBuilder.java` (mhtools, GPLv3+) : fichier sous en-tête GPLv3+, origine citée.
- La lecture suit `patch-iso.py` (npdawson, GPLv3 ; LICENSE à re-vérifier avant tout portage plus large).
- La queue `install_tables` n'est ni écrite ni interprétée (sens inconnu, AGENTS.md §4.1).
- `validate(index)` va plus loin que les références (offset exact d'une entrée, `length <= slotBytes`, pas de doublon/chevauchement) conformément à ARCHITECTURE.md §5.3.

## Alternatives
Écrire la queue `install_tables` pour compatibilité avec mhp3patch.prx : rejetée tant que son rôle n'est pas documenté.
