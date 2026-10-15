// Historique des révisions d'une traduction (docs/ARCHITECTURE.md §7.2).

import 'package:drift/drift.dart';

import 'tdb_database.dart';

/// Copie la révision courante de la traduction [translationId] dans
/// `translation_history`. À appeler dans la même transaction que l'écriture.
Future<void> recordTranslationRevision(
  TdbDatabase db,
  int translationId,
) async {
  final row = await (db.select(db.translations)
        ..where((t) => t.id.equals(translationId)))
      .getSingle();
  await db.into(db.translationHistories).insert(
        TranslationHistoriesCompanion.insert(
          translationId: translationId,
          revision: row.revision,
          text_: row.text_,
          status: row.status,
          authorId: Value(row.authorId),
          changedAt: Value(row.updatedAt),
        ),
      );
}
