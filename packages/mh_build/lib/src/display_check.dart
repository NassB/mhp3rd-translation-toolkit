import 'dart:io';

import 'package:mh_budget/mh_budget.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'font_metrics.dart';
import 'length_profiles_config.dart';

/// Profils et métriques pour les avertissements d'affichage du build
/// (niveaux 3 et 4, docs/ARCHITECTURE.md §8.4). Les avertissements sont
/// informatifs : ils n'arrêtent jamais un build.
final class DisplayCheck {
  /// Voir les champs.
  const DisplayCheck({required this.profiles, required this.metrics});

  final LengthProfiles profiles;
  final GlyphMetrics metrics;

  /// Charge [profilesPath] et [metricsPath] ; `null` si l'un des deux fichiers
  /// est absent (pas de contrôle d'affichage). Un fichier invalide lève
  /// `FormatError`.
  static DisplayCheck? tryLoad({
    String profilesPath = defaultProfiles,
    String metricsPath = defaultFontMetrics,
  }) {
    if (!File(profilesPath).existsSync() || !File(metricsPath).existsSync()) {
      return null;
    }
    final metrics = loadFontMetrics(metricsPath);
    return DisplayCheck(
      profiles: loadLengthProfiles(profilesPath, metrics: metrics),
      metrics: metrics,
    );
  }

  /// Avertissements d'affichage des traductions [translations] du fichier
  /// [fileId], d'après les profils assignés dans [db]. Une chaîne sans profil,
  /// ou dont le profil n'a aucune limite mesurée, n'en produit aucun.
  Future<List<DisplayWarning>> warningsFor(
    TdbDatabase db,
    int fileId,
    List<BuildTranslation> translations,
  ) async {
    final profileOf = await ProfileRepository(db).effectiveProfiles(fileId);
    final out = <DisplayWarning>[];
    for (final t in translations) {
      final id = profileOf[t.sourceId];
      final profile = id == null ? null : profiles[id];
      if (profile == null || !profile.hasLimits) continue;
      for (final issue in evaluateDisplay(t.text, profile, metrics).issues) {
        out.add(
          DisplayWarning(
            tableIdx: t.tableIdx,
            slotIdx: t.slotIdx,
            issue: issue,
          ),
        );
      }
    }
    return out;
  }
}
