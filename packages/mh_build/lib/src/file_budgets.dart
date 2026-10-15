// Budget courant de chaque fichier du projet (jauges du studio).
//
// Sources : docs/ARCHITECTURE.md §8.1-8.3 ; tailles via `FileBudgetTracker`
// (mh_budget), mêmes règles que `buildPatch` (taille = tables + endData).

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'build_patch.dart';
import 'project.dart';

/// Budget d'un fichier avec ses traductions courantes.
final class FileBudget {
  /// Voir les champs.
  const FileBudget({
    required this.fileId,
    required this.origBytes,
    required this.slotBytes,
    required this.rebuiltBytes,
  });

  /// ID DATA.BIN (base 1).
  final int fileId;

  /// Taille originale (slot déchiffré).
  final int origBytes;

  /// Taille de l'emplacement dans `DATA.BIN`.
  final int slotBytes;

  /// Taille reconstruite avec les traductions courantes.
  final int rebuiltBytes;

  /// Politique `strict` respectée (niveaux 1 et 2).
  bool get fitsStrict => rebuiltBytes <= origBytes && fitsSlot;

  /// Niveau 1 respecté : taille alignée sur le secteur <= emplacement.
  bool get fitsSlot => alignUp(rebuiltBytes, sectorSize) <= slotBytes;

  /// Octets restants en politique `strict` (négatif si dépassé).
  int get strictMarginBytes => origBytes - rebuiltBytes;
}

/// Calcule le [FileBudget] de chaque fichier de [fileIds] avec les traductions
/// de [locale] de statut [minStatus] ou plus (`draft` par défaut : la jauge
/// montre le travail en cours, pas seulement ce qui entrerait dans un build).
///
/// Une traduction qui ne correspond plus à l'original (position inexistante)
/// lève [TdbError].
Future<Map<int, FileBudget>> computeFileBudgets({
  required TdbDatabase db,
  required DataBinIndex index,
  required PlainSlotReader readPlain,
  required String locale,
  required Iterable<int> fileIds,
  String minStatus = 'draft',
}) async {
  final all = await eligibleTranslations(
    db,
    locale: locale,
    minStatus: minStatus,
  );
  final byFile = <int, List<BuildTranslation>>{};
  for (final t in all) {
    (byFile[t.fileId] ??= []).add(t);
  }
  final out = <int, FileBudget>{};
  for (final id in fileIds) {
    final entry = index.byId(id);
    final plain = readPlain(entry);
    final tracker = FileBudgetTracker(
      decodeStringTableA(plain, fileId: id),
      fileId: id,
    );
    for (final t in byFile[id] ?? const <BuildTranslation>[]) {
      try {
        tracker.setText(t.tableIdx, t.slotIdx, t.text);
      } on FormatError catch (e) {
        throw TdbError(
          'translation at table ${t.tableIdx} slot ${t.slotIdx}: ${e.message}',
          fileId: id,
        );
      }
    }
    out[id] = FileBudget(
      fileId: id,
      origBytes: plain.length,
      slotBytes: entry.slotBytes,
      rebuiltBytes: tracker.rebuiltBytes,
    );
  }
  return out;
}

/// Ouvre l'ISO et la base de [project], calcule le budget de tous les fichiers
/// importés puis referme tout. Lourd (lit `DATA.BIN`) : à lancer hors du fil
/// d'interface (`Isolate.run`). [config] : registre des versions.
Future<Map<int, FileBudget>> computeProjectBudgets(
  Project project, {
  required String config,
  String minStatus = 'draft',
}) async {
  final session = await IsoSession.open(project.isoPath, config);
  final db = TdbDatabase.openFile(project.dbPath);
  try {
    return await computeFileBudgets(
      db: db,
      index: session.index,
      readPlain: session.readPlain,
      locale: project.locale,
      fileIds: (await importedFileIds(db)).toList()..sort(),
      minStatus: minStatus,
    );
  } finally {
    await db.close();
    session.close();
  }
}
