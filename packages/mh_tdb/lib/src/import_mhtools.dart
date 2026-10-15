// Import dans la base : fichier source décodé, puis traductions d'un dump
// mhtools (docs/ARCHITECTURE.md §7.2, §7.5).

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';

import 'tables/translations.dart';
import 'tdb_database.dart';
import 'translation_history.dart';

/// Texte d'un slot : UTF-8 avec `\n` réel (rendu des jetons).
String slotText(StringSlot s, {int? fileId}) {
  final b = StringBuffer();
  for (final t in tokenizeText(s.raw, fileId: fileId)) {
    switch (t) {
      case NewlineToken():
        b.write('\n');
      case TextToken(:final text):
        b.write(text);
    }
  }
  return b.toString();
}

/// Importe [file] (fichier d'ID [fileId]) dans `game_file` et `source_string`.
///
/// Une table = un `tableIdx` (position dans `file.tables`), un slot = un
/// `slotIdx`. Les alias gardent leur propre ligne avec `alias_of`. Tout ou rien
/// (transaction). Lève [TdbError] si [fileId] est déjà importé.
Future<void> importSourceFile(
  TdbDatabase db, {
  required int fileId,
  required String versionId,
  required int lba,
  required int slotBytes,
  required int origBytes,
  required StringTableFile file,
  String codec = 'string_table_a',
  String? label,
}) {
  return db.transaction(() async {
    final existing = await (db.select(db.gameFiles)
          ..where((t) => t.id.equals(fileId)))
        .getSingleOrNull();
    if (existing != null) {
      throw TdbError('file already imported', fileId: fileId);
    }
    await db.into(db.gameFiles).insert(
          GameFilesCompanion.insert(
            id: Value(fileId),
            versionId: versionId,
            codec: codec,
            lba: lba,
            slotBytes: slotBytes,
            origBytes: origBytes,
            label: Value(label),
          ),
        );
    for (var j = 0; j < file.tables.length; j++) {
      final table = file.tables[j];
      if (table == null) continue;
      final ids = <int>[];
      for (final s in table.slots) {
        final alias = s.aliasOf;
        if (alias != null && (alias < 0 || alias >= ids.length)) {
          throw TdbError(
            'table $j slot ${s.index}: alias target $alias not before it',
            fileId: fileId,
          );
        }
        ids.add(
          await db.into(db.sourceStrings).insert(
                SourceStringsCompanion.insert(
                  fileId: fileId,
                  tableIdx: j,
                  slotIdx: s.index,
                  sourceHash: sha1.convert(s.raw).toString(),
                  sourceText: slotText(s, fileId: fileId),
                  aliasOf: Value(alias == null ? null : ids[alias]),
                ),
              ),
        );
      }
    }
  });
}

/// Applique le dump mhtools [dump] (traduit) sur [original] et écrit les
/// traductions de [locale] pour le fichier [fileId].
///
/// - Seuls les slots non alias sont traités (un alias suit sa cible).
/// - Un texte identique à la source ne crée aucune ligne.
/// - Réimport : la ligne existante est mise à jour (`revision + 1`) si le texte
///   ou le statut change.
///
/// Retourne le nombre de lignes créées ou modifiées. Tout ou rien. Lève
/// [TdbError] si le fichier n'est pas importé, si [original] ne correspond pas
/// aux sources en base ou si [status] est inconnu, [FormatError] si le dump est
/// incompatible avec [original].
Future<int> importMhtoolsTranslations(
  TdbDatabase db, {
  required int fileId,
  required StringTableFile original,
  required MhtoolsDump dump,
  required String locale,
  String status = 'draft',
}) async {
  if (!translationStatuses.contains(status)) {
    throw TdbError('unknown status "$status"', fileId: fileId);
  }
  final translated = importMhtoolsDump(original, dump, fileId: fileId);
  return db.transaction(() async {
    final rows = await (db.select(db.sourceStrings)
          ..where((t) => t.fileId.equals(fileId)))
        .get();
    if (rows.isEmpty) {
      throw TdbError('file not imported', fileId: fileId);
    }
    final byPos = {for (final r in rows) (r.tableIdx, r.slotIdx): r};
    var changed = 0;
    for (var j = 0; j < original.tables.length; j++) {
      final src = original.tables[j];
      final tr = translated.tables[j];
      if (src == null || tr == null) continue;
      for (var i = 0; i < src.slots.length; i++) {
        final row = byPos[(j, i)];
        if (row == null ||
            row.sourceText != slotText(src.slots[i], fileId: fileId)) {
          throw TdbError(
            'table $j slot $i: original does not match the database',
            fileId: fileId,
          );
        }
        if (src.slots[i].aliasOf != null) continue;
        final text = slotText(tr.slots[i], fileId: fileId);
        if (text == row.sourceText) continue;
        final current = await (db.select(db.translations)
              ..where(
                (t) => t.sourceId.equals(row.id) & t.locale.equals(locale),
              ))
            .getSingleOrNull();
        if (current == null) {
          final newId = await db.into(db.translations).insert(
                TranslationsCompanion.insert(
                  sourceId: row.id,
                  locale: locale,
                  text_: text,
                  status: status,
                ),
              );
          await recordTranslationRevision(db, newId);
          changed++;
        } else if (current.text_ != text || current.status != status) {
          await (db.update(db.translations)
                ..where((t) => t.id.equals(current.id)))
              .write(
            TranslationsCompanion(
              text_: Value(text),
              status: Value(status),
              revision: Value(current.revision + 1),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
          await recordTranslationRevision(db, current.id);
          changed++;
        }
      }
    }
    return changed;
  });
}
