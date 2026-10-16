import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../../project/application/project_providers.dart';

/// Profils de longueur et métriques de glyphes, ou la raison pour laquelle ils
/// ne sont pas disponibles.
final class DisplayConfig {
  const DisplayConfig._(this.check, this.error);

  /// Profils et métriques chargés.
  const DisplayConfig.loaded(DisplayCheck check) : this._(check, null);

  /// Fichiers `config/profiles.yaml` ou `config/font_metrics.yaml` absents.
  const DisplayConfig.missing() : this._(null, null);

  /// Fichier invalide (message sans texte du jeu).
  const DisplayConfig.invalid(String error) : this._(null, error);

  final DisplayCheck? check;
  final String? error;
}

/// Charge les profils et les métriques (chemins relatifs au dossier de
/// travail, comme le registre des versions) ; surchargeable dans les tests.
final displayConfigProvider = Provider<DisplayConfig>((ref) {
  try {
    final check = DisplayCheck.tryLoad();
    return check == null
        ? const DisplayConfig.missing()
        : DisplayConfig.loaded(check);
  } on MhError catch (e) {
    return DisplayConfig.invalid(e.message);
  }
});

/// Assignation des profils du projet ouvert.
final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final db = ref.watch(tdbDatabaseProvider);
  return db == null ? null : ProfileRepository(db);
});

/// Profil effectif (`null` : aucun) de chaque chaîne non alias du fichier.
final fileProfilesProvider = FutureProvider.autoDispose
    .family<Map<int, String?>, int>((ref, fileId) async {
      final repo = ref.watch(profileRepositoryProvider);
      return repo == null ? const {} : repo.effectiveProfiles(fileId);
    });

/// Portée d'une assignation de profil.
enum ProfileScope {
  /// La chaîne seule (surcharge).
  string,

  /// Toutes les chaînes de sa table.
  table,

  /// Défaut du fichier.
  file,
}

/// Assigne ou efface un profil, puis recharge les profils du fichier. Les
/// erreurs ([MhError]) remontent à l'appelant pour affichage.
class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  Future<void> assign({
    required int fileId,
    required ProfileScope scope,
    required String? profileId,
    int? tableIdx,
    int? sourceId,
  }) async {
    final repo = _ref.read(profileRepositoryProvider);
    if (repo == null) throw StateError('no project open');
    final known = _ref.read(displayConfigProvider).check?.profiles.ids;
    switch (scope) {
      case ProfileScope.string:
        await repo.setStringProfile(sourceId!, profileId, knownIds: known);
      case ProfileScope.table:
        await repo.setTableProfile(
          fileId,
          tableIdx!,
          profileId,
          knownIds: known,
        );
      case ProfileScope.file:
        await repo.setFileProfile(fileId, profileId, knownIds: known);
    }
    _ref.invalidate(fileProfilesProvider(fileId));
  }
}

/// Actions d'assignation des profils.
final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);
