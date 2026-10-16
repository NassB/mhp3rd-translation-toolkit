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
    required this.sourceId,
    required this.fileId,
    required this.tableIdx,
    required this.slotIdx,
    required this.sourceHash,
    required this.text,
  });

  /// Id de la ligne `source_string`.
  final int sourceId;

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
        sourceId: r.readTable(src).id,
        fileId: r.readTable(src).fileId,
        tableIdx: r.readTable(src).tableIdx,
        slotIdx: r.readTable(src).slotIdx,
        sourceHash: r.readTable(src).sourceHash,
        text: r.readTable(tr).text_,
      ),
  ];
}

/// Instantané de révision de la base (docs/ARCHITECTURE.md §9.1, étape 2) :
/// somme des `revision` de toutes les lignes `translation` (croît à chaque
/// ajout ou modification ; 0 si la base est vide).
Future<int> tdbRevision(TdbDatabase db) async {
  final sum = db.translations.revision.sum();
  final row =
      await (db.selectOnly(db.translations)..addColumns([sum])).getSingle();
  return row.read(sum) ?? 0;
}

/// Insère une ligne `build` et retourne son id.
Future<int> recordBuild(
  TdbDatabase db, {
  required String isoMd5,
  required int tdbRevision,
  required String toolkitVersion,
  required String profile,
  required String status,
  required String reportJson,
}) =>
    db.into(db.builds).insert(
          BuildsCompanion.insert(
            isoMd5: isoMd5,
            tdbRevision: tdbRevision,
            toolkitVersion: toolkitVersion,
            profile: profile,
            status: status,
            reportJson: Value(reportJson),
          ),
        );

/// Dernières lignes `build`, la plus récente d'abord.
Future<List<BuildRow>> recentBuilds(TdbDatabase db, {int limit = 20}) =>
    (db.select(db.builds)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
