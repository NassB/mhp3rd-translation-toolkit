// Profils de longueur (docs/ARCHITECTURE.md §8.4).
//
// Un profil décrit les contraintes d'affichage d'un type d'écran : largeur
// maximale en pixels (niveau 3) et nombre de lignes maximal (niveau 4). Les
// valeurs viennent de mesures en jeu (docs/CALIBRATION.md) : **0 veut dire
// « non mesuré »**, et un profil sans limite ne produit jamais d'avertissement.

/// Contraintes d'affichage d'un contexte.
final class LengthProfile {
  /// Voir les champs.
  const LengthProfile({
    required this.id,
    this.description = '',
    this.fontContext,
    this.maxPx = 0,
    this.maxLines = 0,
    this.paginated = false,
  });

  /// Identifiant stable (`menu_label`, `dialogue`…).
  final String id;

  /// À quel écran il correspond (information).
  final String description;

  /// Contexte de police (`FontContext.id`, ex. `px7`), `null` tant que le
  /// pas de ce type d'écran n'est pas mesuré.
  final String? fontContext;

  /// Largeur maximale d'une ligne en pixels de la PSP ; 0 : non mesurée.
  final int maxPx;

  /// Nombre de lignes maximal d'une page ; 0 : non mesuré.
  final int maxLines;

  /// Le texte est découpé en pages (dialogues).
  final bool paginated;

  /// Vrai si la largeur peut être contrôlée : limite connue **et** police
  /// connue.
  bool get checksWidth => maxPx > 0 && fontContext != null;

  /// Vrai si le nombre de lignes peut être contrôlé.
  bool get checksLines => maxLines > 0;

  /// Vrai si le profil contraint quelque chose ; sinon il ne produit aucun
  /// avertissement.
  bool get hasLimits => checksWidth || checksLines;
}

/// Ensemble de profils indexés par identifiant.
final class LengthProfiles {
  /// Voir les champs ; les identifiants doivent être uniques.
  LengthProfiles(Iterable<LengthProfile> profiles) : byId = _index(profiles);

  final Map<String, LengthProfile> byId;

  /// Profil [id], ou `null`.
  LengthProfile? operator [](String id) => byId[id];

  /// Identifiants connus.
  Set<String> get ids => byId.keys.toSet();

  /// Profils dans l'ordre de déclaration.
  Iterable<LengthProfile> get all => byId.values;

  static Map<String, LengthProfile> _index(Iterable<LengthProfile> profiles) {
    final out = <String, LengthProfile>{};
    for (final p in profiles) {
      if (out.containsKey(p.id)) {
        throw ArgumentError.value(p.id, 'profiles', 'duplicate profile id');
      }
      out[p.id] = p;
    }
    return Map.unmodifiable(out);
  }
}
