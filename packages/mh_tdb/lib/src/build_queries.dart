// Requêtes de lecture pour le pipeline de build (docs/ARCHITECTURE.md §9.1,
// étape « Select »).

import 'package:drift/drift.dart';
import 'package:mh_binary/mh_binary.dart';

import 'tables/translations.dart';
import 'tdb_database.dart';

/// Une traduction éligible à un build, avec la position de sa source.
final class BuildTranslation {
  /// Voir les champs.
  const BuildTranslation({
    required this.fileId,
    required this.tableIdx,
    required this.slotIdx,
    required this.sourceHash,
    required this.text,
  });

  /// ID DATA.BIN (base 1).
  final int fileId;

  /// Position de la table dans le fichier.
  final int tableIdx;

  /// Position du slot dans la table.
  final int slotIdx;

  /// SHA-1 hexadécimal des octets d'origine de la source.
  final String sourceHash;

  /// Texte traduit (UTF-8, `\n` réel).
  final String text;
}

/// Traductions de [locale] dont le statut est [minStatus] ou plus (ordre de
/// [translationStatuses]), triées par fichier, table, slot.
///
/// Lève [TdbError] si [minStatus] est inconnu.
Future<List<BuildTranslation>> eligibleTranslations(
  TdbDatabase db, {
  required String locale,
  required String minStatus,
}) async {
  final from = translationStatuses.indexOf(minStatus);
  if (from < 0) throw TdbError('unknown status "$minStatus"');
  final statuses = translationStatuses.sublist(from);
  final src = db.sourceStrings;
  final tr = db.translations;
  final query = db.select(tr).join([
    innerJoin(src, src.id.equalsExp(tr.sourceId)),
  ])
    ..where(tr.locale.equals(locale) & tr.status.isIn(statuses))
    ..orderBy([
      OrderingTerm.asc(src.fileId),
      OrderingTerm.asc(src.tableIdx),
      OrderingTerm.asc(src.slotIdx),
    ]);
  final rows = await query.get();
  return [
    for (final r in rows)
      BuildTranslation(
        fileId: r.readTable(src).fileId,
        tableIdx: r.readTable(src).tableIdx,
        slotIdx: r.readTable(src).slotIdx,
        sourceHash: r.readTable(src).sourceHash,
        text: r.readTable(tr).text_,
      ),
  ];
}
