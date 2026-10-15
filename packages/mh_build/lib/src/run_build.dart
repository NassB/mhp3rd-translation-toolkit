// Pipeline de build complet vers une copie d'ISO (docs/ARCHITECTURE.md §9.1,
// étapes 2 et 9-11 ; les étapes 3-8 sont dans `buildPatch`).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';
import 'package:mh_tdb/mh_tdb.dart';

import 'build_patch.dart';
import 'project.dart';
import 'validated_files.dart';

/// Statuts enregistrés dans `build.status`.
abstract final class BuildStatus {
  /// Patch appliqué et vérifié.
  static const String ok = 'ok';

  /// Aucune traduction éligible : rien à construire.
  static const String nothingToBuild = 'nothing_to_build';

  /// Au moins un fichier dépasse son budget : ISO non écrit.
  static const String budgetExceeded = 'budget_exceeded';

  /// La relecture de l'artefact diffère de ce qui était attendu.
  static const String verifyFailed = 'verify_failed';
}

/// Issue d'un [runBuild].
final class BuildRun {
  /// Voir les champs.
  BuildRun({
    required this.status,
    required this.buildId,
    required this.tdbRevision,
    required this.result,
    required List<String> verifyErrors,
    required this.reportJson,
  }) : verifyErrors = List.unmodifiable(verifyErrors);

  /// Valeur de [BuildStatus].
  final String status;

  /// Id de la ligne `build`.
  final int buildId;

  /// Instantané de révision utilisé.
  final int tdbRevision;

  /// Résultat de `buildPatch`.
  final BuildResult result;

  /// Écarts constatés à la relecture (sans texte du jeu).
  final List<String> verifyErrors;

  /// Rapport JSON enregistré dans `build.report_json`.
  final String reportJson;

  /// Vrai si l'ISO écrit est complet et vérifié.
  bool get ok => status == BuildStatus.ok;
}

/// Construit les traductions de [locale] et les écrit dans [outPath], copie de
/// [iso] (la source n'est jamais modifiée, voir `applyPatch`).
///
/// Enregistre une ligne `build` dans tous les cas (sauf erreur d'E/S ou de
/// base inattendue). Un dépassement de budget n'écrit aucun ISO.
Future<BuildRun> runBuild({
  required TdbDatabase db,
  required IsoImage iso,
  required DataBinIndex index,
  required PlainSlotReader readPlain,
  required String locale,
  required String outPath,
  required String toolkitVersion,
  String profile = 'nightly',
  String minStatus = 'translated',
  BudgetPolicy policy = BudgetPolicy.strict,
  Set<int> slotAllowedFileIds = const {},
}) async {
  final revision = await tdbRevision(db);
  final result = await buildPatch(
    db: db,
    index: index,
    readPlain: readPlain,
    locale: locale,
    minStatus: minStatus,
    policy: policy,
    slotAllowedFileIds: slotAllowedFileIds,
  );

  var status = BuildStatus.ok;
  final errors = <String>[];
  if (result.reports.isEmpty) {
    status = BuildStatus.nothingToBuild;
  } else if (!result.ok) {
    status = BuildStatus.budgetExceeded;
  } else {
    final patch = result.patch!;
    await applyPatch(iso, patch, index, outPath: outPath);
    errors.addAll(_verify(outPath, iso, index, patch, result.applied));
    if (errors.isNotEmpty) status = BuildStatus.verifyFailed;
  }

  final reportJson = jsonEncode({
    'iso_md5': iso.version.isoMd5,
    'tdb_revision': revision,
    'toolkit_version': toolkitVersion,
    'profile': profile,
    'locale': locale,
    'status': status,
    'files': [for (final r in result.reports) r.toJson()],
    'verify_errors': errors,
  });
  final id = await recordBuild(
    db,
    isoMd5: iso.version.isoMd5,
    tdbRevision: revision,
    toolkitVersion: toolkitVersion,
    profile: profile,
    status: status,
    reportJson: reportJson,
  );
  return BuildRun(
    status: status,
    buildId: id,
    tdbRevision: revision,
    result: result,
    verifyErrors: errors,
    reportJson: reportJson,
  );
}

/// Étape 10 : relit les blocs dans [outPath], les compare au patch, puis
/// déchiffre, décode et compare chaque texte éligible. Les messages ne
/// contiennent aucun texte du jeu.
List<String> _verify(
  String outPath,
  IsoImage iso,
  DataBinIndex index,
  PatchFile patch,
  List<BuildTranslation> applied,
) {
  const cipher = DataCipher();
  final errors = <String>[];
  final base = iso.dataBin.offset;
  final raf = File(outPath).openSync();
  try {
    for (final b in patch.blocks) {
      final entry = index.entries.firstWhere(
        (e) => e.slotBytes > 0 && e.offset == b.offset,
      );
      raf.setPositionSync(base + b.offset);
      final back = Uint8List(b.data.length);
      var got = 0;
      while (got < back.length) {
        final n = raf.readIntoSync(back, got);
        if (n == 0) break;
        got += n;
      }
      if (got != back.length || !_same(back, b.data)) {
        errors.add('file ${entry.id}: written block differs from the patch');
        continue;
      }
      final plain = entry.encrypted ? cipher.decrypt(back, entry.lba) : back;
      final StringTableFile file;
      try {
        file = decodeStringTableA(plain, fileId: entry.id);
      } on FormatError {
        errors.add('file ${entry.id}: rebuilt file does not decode');
        continue;
      }
      for (final t in applied.where((t) => t.fileId == entry.id)) {
        final table = file.tables[t.tableIdx];
        if (table == null ||
            slotText(table.slots[t.slotIdx], fileId: entry.id) != t.text) {
          errors.add(
            'file ${entry.id}: table ${t.tableIdx} slot ${t.slotIdx} '
            'does not hold the expected translation',
          );
        }
      }
    }
  } finally {
    raf.closeSync();
  }
  return errors;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Résumé d'un build, léger et transmissible entre isolates (ni patch ni
/// octets du jeu).
final class BuildSummary {
  /// Voir les champs.
  BuildSummary({
    required this.status,
    required this.buildId,
    required this.tdbRevision,
    required List<BudgetReport> files,
    required List<String> verifyErrors,
    required this.reportJson,
    required this.outPath,
  })  : files = List.unmodifiable(files),
        verifyErrors = List.unmodifiable(verifyErrors);

  /// Valeur de [BuildStatus].
  final String status;
  final int buildId;
  final int tdbRevision;

  /// Un rapport de budget par fichier construit.
  final List<BudgetReport> files;
  final List<String> verifyErrors;
  final String reportJson;

  /// Chemin de l'ISO demandé (écrit seulement si [ok]).
  final String outPath;

  /// Vrai si l'ISO est complet et vérifié.
  bool get ok => status == BuildStatus.ok;
}

/// Construit le projet [project] vers [outPath] : ouvre l'ISO (MD5 vérifié) et
/// la base, lance [runBuild], referme tout. Lourd (lit `DATA.BIN`) : à lancer
/// hors du fil d'interface (`Isolate.run`). La liste blanche de la politique
/// `slot` vient de [validatedFiles] (`config/validated_files.yaml`).
Future<BuildSummary> runProjectBuild(
  Project project, {
  required String config,
  required String outPath,
  String profile = 'nightly',
  String minStatus = 'translated',
  BudgetPolicy policy = BudgetPolicy.strict,
  String validatedFiles = 'config/validated_files.yaml',
}) async {
  final session = await IsoSession.open(project.isoPath, config);
  final db = TdbDatabase.openFile(project.dbPath);
  try {
    final parent = File(outPath).absolute.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    final run = await runBuild(
      db: db,
      iso: session.image,
      index: session.index,
      readPlain: session.readPlain,
      locale: project.locale,
      outPath: outPath,
      toolkitVersion: toolkitVersion,
      profile: profile,
      minStatus: minStatus,
      policy: policy,
      slotAllowedFileIds: loadValidatedFiles(validatedFiles),
    );
    return BuildSummary(
      status: run.status,
      buildId: run.buildId,
      tdbRevision: run.tdbRevision,
      files: run.result.reports,
      verifyErrors: run.verifyErrors,
      reportJson: run.reportJson,
      outPath: outPath,
    );
  } finally {
    await db.close();
    session.close();
  }
}
