// Association des profils de longueur aux fichiers, tables et chaînes
// (docs/ARCHITECTURE.md §7.2, §8.4).
//
// Les définitions des profils vivent dans `config/profiles.yaml` ; la base ne
// garde que l'**identifiant** du profil : par fichier (`game_file.context_profile`,
// valeur par défaut) et par chaîne (`source_string.context_profile`,
// surcharge). Une assignation « table » écrit la surcharge sur toutes les
// chaînes non alias de la table. Un identifiant `null` efface l'assignation.

import 'package:drift/drift.dart';
import 'package:mh_binary/mh_binary.dart';

import 'tdb_database.dart';

/// Lecture et écriture des profils assignés.
final class ProfileRepository {
  /// Voir les champs.
  ProfileRepository(this.db);

  /// Base de traduction.
  final TdbDatabase db;

  void _check(String? profileId, Set<String>? knownIds) {
    if (profileId == null) return;
    if (profileId.trim().isEmpty) throw const TdbError('empty profile id');
    if (knownIds != null && !knownIds.contains(profileId)) {
      throw TdbError('unknown profile "$profileId"');
    }
  }

  /// Profil par défaut du fichier [fileId] (`null` : aucun). Lève [TdbError]
  /// si le fichier n'est pas importé ou si [profileId] n'est pas dans
  /// [knownIds].
  Future<void> setFileProfile(
    int fileId,
    String? profileId, {
    Set<String>? knownIds,
  }) async {
    _check(profileId, knownIds);
    final n = await (db.update(db.gameFiles)..where((t) => t.id.equals(fileId)))
        .write(GameFilesCompanion(contextProfile: Value(profileId)));
    if (n == 0) throw TdbError('file not imported', fileId: fileId);
  }

  /// Profil par défaut du fichier, ou `null`.
  Future<String?> fileProfile(int fileId) async {
    final row = await (db.select(db.gameFiles)
          ..where((t) => t.id.equals(fileId)))
        .getSingleOrNull();
    if (row == null) throw TdbError('file not imported', fileId: fileId);
    return row.contextProfile;
  }

  /// Profil de toutes les chaînes non alias de la table [tableIdx] du fichier ;
  /// retourne leur nombre. Lève [TdbError] si la table n'a aucune chaîne.
  Future<int> setTableProfile(
    int fileId,
    int tableIdx,
    String? profileId, {
    Set<String>? knownIds,
  }) async {
    _check(profileId, knownIds);
    final n = await (db.update(db.sourceStrings)
          ..where(
            (t) =>
                t.fileId.equals(fileId) &
                t.tableIdx.equals(tableIdx) &
                t.aliasOf.isNull(),
          ))
        .write(SourceStringsCompanion(contextProfile: Value(profileId)));
    if (n == 0) {
      throw TdbError('no string in table $tableIdx', fileId: fileId);
    }
    return n;
  }

  /// Profil d'une chaîne (surcharge). Lève [TdbError] pour une chaîne
  /// inconnue ou un alias (il suit sa cible).
  Future<void> setStringProfile(
    int sourceId,
    String? profileId, {
    Set<String>? knownIds,
  }) async {
    _check(profileId, knownIds);
    final row = await (db.select(db.sourceStrings)
          ..where((t) => t.id.equals(sourceId)))
        .getSingleOrNull();
    if (row == null) throw TdbError('unknown source string $sourceId');
    if (row.aliasOf != null) {
      throw TdbError(
        'source string $sourceId is an alias: set its target',
        fileId: row.fileId,
      );
    }
    await (db.update(db.sourceStrings)..where((t) => t.id.equals(sourceId)))
        .write(SourceStringsCompanion(contextProfile: Value(profileId)));
  }

  /// Profil effectif d'une chaîne : sa surcharge, sinon le défaut de son
  /// fichier, sinon `null`.
  Future<String?> effectiveProfile(int sourceId) async {
    final row = await (db.select(db.sourceStrings)
          ..where((t) => t.id.equals(sourceId)))
        .getSingleOrNull();
    if (row == null) throw TdbError('unknown source string $sourceId');
    return row.contextProfile ?? await fileProfile(row.fileId);
  }

  /// Profil effectif de chaque chaîne non alias du fichier (`null` : aucun).
  Future<Map<int, String?>> effectiveProfiles(int fileId) async {
    final fallback = await fileProfile(fileId);
    final rows = await (db.select(db.sourceStrings)
          ..where((t) => t.fileId.equals(fileId) & t.aliasOf.isNull()))
        .get();
    return {for (final r in rows) r.id: r.contextProfile ?? fallback};
  }

  /// Nombre de chaînes non alias par profil effectif du fichier ; la clé
  /// `null` regroupe celles sans profil.
  Future<Map<String?, int>> countByProfile(int fileId) async {
    final out = <String?, int>{};
    for (final p in (await effectiveProfiles(fileId)).values) {
      out[p] = (out[p] ?? 0) + 1;
    }
    return out;
  }
}
