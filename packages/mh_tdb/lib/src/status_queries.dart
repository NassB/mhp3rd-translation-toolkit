// Requêtes de synthèse pour `mhtk status` et `mhtk extract`.

import 'package:drift/drift.dart';

import 'tables/translations.dart';
import 'tdb_database.dart';

/// Synthèse du contenu de la base.
final class TdbStatus {
  /// Voir les champs.
  const TdbStatus({
    required this.files,
    required this.strings,
    required this.translationsByStatus,
  });

  /// Nombre de fichiers dans `game_file`.
  final int files;

  /// Nombre de lignes dans `source_string` (alias compris).
  final int strings;

  /// Nombre de traductions par statut (tous les statuts, 0 inclus).
  final Map<String, int> translationsByStatus;
}

/// IDs DATA.BIN déjà présents dans `game_file`.
Future<Set<int>> importedFileIds(TdbDatabase db) async {
  final rows = await db.select(db.gameFiles).get();
  return {for (final r in rows) r.id};
}

/// Compte fichiers, chaînes et traductions par statut pour [locale].
Future<TdbStatus> tdbStatus(TdbDatabase db, {required String locale}) async {
  Future<int> count(TableInfo<Table, dynamic> t) async {
    final c = countAll();
    final row = await (db.selectOnly(t)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  final byStatus = {for (final s in translationStatuses) s: 0};
  final tr = db.translations;
  final c = countAll();
  final rows = await (db.selectOnly(tr)
        ..addColumns([tr.status, c])
        ..where(tr.locale.equals(locale))
        ..groupBy([tr.status]))
      .get();
  for (final r in rows) {
    byStatus[r.read(tr.status)!] = r.read(c) ?? 0;
  }
  return TdbStatus(
    files: await count(db.gameFiles),
    strings: await count(db.sourceStrings),
    translationsByStatus: byStatus,
  );
}
