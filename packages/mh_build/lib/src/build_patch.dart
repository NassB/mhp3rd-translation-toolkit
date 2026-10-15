// Pipeline de build, étapes Select → Patch (docs/ARCHITECTURE.md §9.1).
//
// Disposition d'un fichier reconstruit (RebuildPluginA.java, `compile` :
// remplissage de zéros jusqu'à `size - enddataSize`, puis `enddata`) :
//
//   tables encodées | zéros | endData | (zéros jusqu'au secteur)
//
// `endData` reste ainsi à sa position d'origine tant que le texte ne grandit
// pas ; son contenu est inconnu (docs/FORMATS/string_table_a.md).

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';

/// Lit le slot d'origine **déchiffré** d'une entrée (fourni par l'appelant).
typedef PlainSlotReader = Uint8List Function(DataBinEntry entry);

/// Résultat de [buildPatch].
final class BuildResult {
  /// Voir les champs.
  BuildResult({required this.patch, required List<BudgetReport> reports})
      : reports = List.unmodifiable(reports);

  /// Patch prêt à appliquer ; `null` si un budget est dépassé ou s'il n'y a
  /// rien à patcher.
  final PatchFile? patch;

  /// Un rapport par fichier sélectionné, par ID croissant.
  final List<BudgetReport> reports;

  /// Vrai si tous les budgets sont respectés.
  bool get ok => reports.every((r) => r.isOk);
}

/// Construit le patch des traductions de [locale] de statut [minStatus] ou
/// plus (`translated` : nightly ; `reviewed` : release).
///
/// Tout ou rien : si un fichier dépasse son budget, [BuildResult.patch] est
/// `null` et les rapports de tous les fichiers sont renvoyés. Lève [TdbError]
/// si la base ne correspond pas à l'original (SHA-1, position inexistante).
Future<BuildResult> buildPatch({
  required TdbDatabase db,
  required DataBinIndex index,
  required PlainSlotReader readPlain,
  required String locale,
  String minStatus = 'translated',
  BudgetPolicy policy = BudgetPolicy.strict,
  Set<int> slotAllowedFileIds = const {},
}) async {
  final translations = await eligibleTranslations(
    db,
    locale: locale,
    minStatus: minStatus,
  );
  final byFile = <int, List<BuildTranslation>>{};
  for (final t in translations) {
    (byFile[t.fileId] ??= []).add(t);
  }

  const cipher = DataCipher();
  final reports = <BudgetReport>[];
  final blocks = <PatchBlock>[];
  for (final fileId in byFile.keys.toList()..sort()) {
    final entry = index.byId(fileId);
    final plain = readPlain(entry);
    final model = decodeStringTableA(plain, fileId: fileId);
    final rebuilt = _applyTranslations(model, byFile[fileId]!, fileId);

    final tables = encodeStringTableA(rebuilt, fileId: fileId);
    final rebuiltBytes = tables.length + model.endData.length;
    final report = evaluateFileBudget(
      fileId: fileId,
      origBytes: plain.length,
      rebuiltBytes: rebuiltBytes,
      slotBytes: entry.slotBytes,
      policy: policy,
      slotAllowedFileIds: slotAllowedFileIds,
    );
    reports.add(report);
    if (!report.isOk) continue;

    final w = ByteWriter()
      ..bytes(tables)
      ..fill(max(0, plain.length - rebuiltBytes)) // 0 si agrandi (slot)
      ..bytes(model.endData)
      ..padTo(sectorSize);
    final data = w.toBytes();
    blocks.add(
      PatchBlock(
        offset: entry.offset,
        data: entry.encrypted ? cipher.encrypt(data, entry.lba) : data,
      ),
    );
  }

  if (reports.isEmpty || !reports.every((r) => r.isOk)) {
    return BuildResult(patch: null, reports: reports);
  }
  final patch = PatchFile(blocks)..validate(index);
  return BuildResult(patch: patch, reports: reports);
}

StringTableFile _applyTranslations(
  StringTableFile model,
  List<BuildTranslation> translations,
  int fileId,
) {
  TdbError fail(String msg) => TdbError(msg, fileId: fileId);
  final byPos = <(int, int), BuildTranslation>{};
  for (final t in translations) {
    final table =
        t.tableIdx < model.tables.length ? model.tables[t.tableIdx] : null;
    if (table == null || t.slotIdx >= table.slots.length) {
      throw fail('translation at table ${t.tableIdx} slot ${t.slotIdx}: '
          'no such slot in the original');
    }
    final slot = table.slots[t.slotIdx];
    if (slot.aliasOf != null) {
      throw fail('translation on alias slot ${t.slotIdx} of '
          'table ${t.tableIdx}');
    }
    if (sha1.convert(slot.raw).toString() != t.sourceHash) {
      throw fail('source hash mismatch at table ${t.tableIdx} slot '
          '${t.slotIdx}: the database is stale');
    }
    byPos[(t.tableIdx, t.slotIdx)] = t;
  }

  final tables = <StringTable?>[];
  for (var j = 0; j < model.tables.length; j++) {
    final table = model.tables[j];
    if (table == null) {
      tables.add(null);
      continue;
    }
    final slots = <StringSlot>[];
    for (final s in table.slots) {
      final alias = s.aliasOf;
      final Uint8List raw;
      if (alias != null) {
        raw = slots[alias].raw;
      } else {
        final t = byPos[(j, s.index)];
        raw = t == null ? s.raw : Uint8List.fromList(utf8.encode(t.text));
      }
      slots.add(StringSlot(index: s.index, raw: raw, aliasOf: alias));
    }
    tables.add(
      StringTable(originalOffsets: table.originalOffsets, slots: slots),
    );
  }
  return StringTableFile(
    unknownHeader: model.unknownHeader,
    tables: tables,
    endData: Uint8List(0),
  );
}
