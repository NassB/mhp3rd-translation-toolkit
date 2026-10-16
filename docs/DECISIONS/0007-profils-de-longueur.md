# 0007 — Profils de longueur : définitions en YAML, assignation en base

Date : 2026-10-16. Statut : appliquée (T39).

## Contexte

ARCHITECTURE §7.2 et §8.4 prévoient des profils de longueur (`max_px`, `max_lines`, police) assignés par fichier (`game_file.context_profile`) et par chaîne (`source_string.context_profile`), avec une table `length_profile`. Les mesures en jeu (docs/CALIBRATION.md §5) montrent que le **pas des caractères dépend de l'élément d'interface** (6, 7 ou 9 px), pas du fichier, et qu'aucune limite de largeur n'est encore mesurée.

## Décision

- Les **définitions** des profils vivent dans `config/profiles.yaml` (versionné, relu en revue) : `max_px`, `max_lines`, `font_context` (un id de `config/font_metrics.yaml`), `paginated`, `description`. **0 / absent = non mesuré**, et un profil sans limite ne produit aucun avertissement.
- La base ne stocke que l'**identifiant** du profil : défaut du fichier (`game_file.context_profile`) et surcharge par chaîne (`source_string.context_profile`). Une assignation « table » écrit la surcharge sur les chaînes non alias de la table (aucun nouveau champ). Profil effectif d'une chaîne : sa surcharge, sinon le défaut de son fichier.
- **Pas de table `length_profile`, pas de migration v3** : une seule source de vérité (le YAML), pas de risque de divergence entre la base et le dépôt. Si une édition de profils depuis le studio devient nécessaire, on rouvrira la question.
- Un identifiant assigné doit exister dans le YAML (contrôle fait par l'appelant avec `knownIds`) ; un `font_context` doit exister dans `font_metrics.yaml`.
- Les profils fournis ne sont **pas rattachés à un contexte de police** : seule la liste de menu du village (7 px) et la fenêtre de message du village (6 px) ont été mesurées, sur un seul écran chacune ; une association par type de profil serait une devinette.

## Alternatives écartées

- Table `length_profile` en base (ARCHITECTURE §7.2) : duplique le YAML, oblige une migration et une synchronisation.
- Profil par table dans une nouvelle table d'assignation : plus fidèle à l'usage (les tables de `DATA.BIN` correspondent à des écrans) mais ajoute un schéma ; l'écriture sur les chaînes suffit tant que les tables ne changent pas.
