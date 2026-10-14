---
name: binary-codec
description: Procédure pour implémenter ou modifier un codec binaire (table de texte, TOC, patch, quête, PAC, GIM) ou le chiffrement de DATA.BIN, avec round-trip bit à bit et mesure exacte de taille.
paths: packages/mh_binary/**, packages/mh_databin/**, packages/mh_formats/**, packages/mh_budget/**
---

# Implémenter un codec binaire

## Ordre obligatoire

1. **Référence** : obtenir la structure via `/ref-lookup` ou `docs/FORMATS/<format>.md`. Sans source : arrêt, question dans PROGRESS.md.
2. **Documentation** : créer ou compléter `docs/FORMATS/<format>.md` (tableau offset/taille/type/champ, source, inconnues).
3. **Builder de fixtures** : `packages/<pkg>/test/builders/<format>_builder.dart`, qui génère des fichiers synthétiques valides, y compris cas limites.
4. **Tests d'abord** :
   - round-trip `encode(decode(x)) == x` sur fixtures ;
   - `measure(m) == encode(m).length` ;
   - erreurs : fichier tronqué, offset hors bornes, compteur incohérent → `FormatError` avec offset ;
   - test `@Tags(['integration'])` sur données réelles, `skip` si `MHP3_ISO`/`MHP3_DATABIN` absent.
5. **Implémentation** : `FormatCodec<T>` (`sniff`, `decode`, `encode`, `measure`), modèle immuable, champs inconnus conservés.
6. **Vérification** : `/check <paquet>`.

## Spécificités connues

- `string_table_a` : lire et conserver les offsets ; détecter les alias (offsets identiques) ; réémettre dans l'ordre d'origine. Ne pas reproduire la relecture séquentielle de mhtools.
- Chiffrement DATA.BIN : fonction pure `(Uint8List data, int lba)`, constantes recopiées depuis la référence, test de round-trip par secteur.
- Patch `MHP3RD_DATA.BIN` : `u32 count`, `count × (u32 offset, u32 length)` LE, en-tête aligné sur 16, longueurs multiples de 2048.
- Tailles alignées sur 2048 ; comparer à `slotBytes` (bloquant) et à la taille originale (politique `strict`).

## Style

- `ByteReader`/`ByteWriter` de `mh_binary` uniquement, jamais d'accès `ByteData` épars.
- Commentaire de structure en tableau au-dessus de chaque type, avec la ligne `Source : ...`.
- Pas d'optimisation prématurée : la lisibilité d'abord, mesurer avant d'optimiser le chiffrement.
