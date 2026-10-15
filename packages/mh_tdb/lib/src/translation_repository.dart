// Accès aux fichiers, chaînes et traductions pour les interfaces (studio).
//
// Sources : docs/ARCHITECTURE.md §7.2 (schéma), §7.4 (concurrence optimiste :
// chaque écriture envoie `revision` ; en cas de conflit le client reçoit la
// version courante). L'historique des révisions viendra avec le schéma v2.

import 'package:drift/drift.dart';
import 'package:mh_binary/mh_binary.dart';

import 'tables/translations.dart';
import 'tdb_database.dart';
import 'translation_history.dart';

/// Avancement d'un fichier pour une locale.
final class FileProgress {
  /// Voir les champs.
  const FileProgress({
    required this.id,
    required this.versionId,
    required this.codec,
    required this.lba,
    required this.slotBytes,
    required this.origBytes,
    required this.label,
    required this.totalStrings,
    required this.byStatus,
  });

  /// ID DATA.BIN (base 1).
  final int id;
  final String versionId;
  final String codec;
  final int lba;
  final int slotBytes;
  final int origBytes;
  final String? label;

  /// Chaînes traduisibles (alias exclus).
  final int totalStrings;

  /// Nombre de chaînes par statut ; `untranslated` inclut les chaînes sans
  /// ligne `translation`.
  final Map<String, int> byStatus;

  /// Chaînes au statut `translated` ou plus.
  int get doneStrings =>
      (byStatus['translated'] ?? 0) +
      (byStatus['reviewed'] ?? 0) +
      (byStatus['locked'] ?? 0);
}

/// Traduction d'une chaîne telle que stockée.
final class TranslationInfo {
  /// Voir les champs.
  const TranslationInfo({
    required this.id,
    required this.text,
    required this.status,
    required this.revision,
    required this.updatedAt,
    required this.authorId,
  });

  /// Id de la ligne `translation`.
  final int id;
  final String text;
  final String status;
  final int revision;
  final DateTime updatedAt;
  final String? authorId;
}

/// Une révision passée d'une traduction.
final class TranslationRevision {
  /// Voir les champs.
  const TranslationRevision({
    required this.revision,
    required this.text,
    required this.status,
    required this.authorId,
    required this.changedAt,
  });

  final int revision;
  final String text;
  final String status;
  final String? authorId;
  final DateTime changedAt;
}

/// Une chaîne source avec sa traduction éventuelle.
final class SlotView {
  /// Voir les champs.
  const SlotView({
    required this.sourceId,
    required this.fileId,
    required this.tableIdx,
    required this.slotIdx,
    required this.sourceText,
    required this.aliasOfSlot,
    required this.translation,
  });

  /// Id de la ligne `source_string`.
  final int sourceId;
  final int fileId;
  final int tableIdx;
  final int slotIdx;
  final String sourceText;

  /// `slotIdx` de la chaîne cible si ce slot est un alias (lecture seule).
  final int? aliasOfSlot;

  /// `null` tant que la chaîne n'a pas de ligne `translation`.
  final TranslationInfo? translation;

  /// Vrai si le slot partage la chaîne d'un autre.
  bool get isAlias => aliasOfSlot != null;
}

/// Résultat de [TranslationRepository.saveTranslation].
sealed class SaveResult {
  const SaveResult();
}

/// Écriture acceptée ; [translation] porte la nouvelle révision.
final class SaveOk extends SaveResult {
  /// Voir les champs.
  const SaveOk(this.translation);

  /// Traduction enregistrée.
  final TranslationInfo translation;
}

/// Écriture refusée : la ligne a changé (ou existe déjà, ou a disparu).
final class SaveConflict extends SaveResult {
  /// Voir les champs.
  const SaveConflict(this.current);

  /// Version courante en base ; `null` si la ligne n'existe pas.
  final TranslationInfo? current;
}

/// Lecture et écriture des traductions d'une [locale].
final class TranslationRepository {
  /// Voir les champs.
  TranslationRepository(this.db, {required this.locale});

  /// Base de traduction.
  final TdbDatabase db;

  /// Locale cible (`fr`…).
  final String locale;

  /// Fichiers importés, par ID, avec leur avancement.
  Future<List<FileProgress>> listFiles() async {
    final files = await (db.select(db.gameFiles)
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

    final src = db.sourceStrings;
    final totalCount = countAll();
    final totals = await (db.selectOnly(src)
          ..addColumns([src.fileId, totalCount])
          ..where(src.aliasOf.isNull())
          ..groupBy([src.fileId]))
        .get();
    final totalByFile = {
      for (final r in totals) r.read(src.fileId)!: r.read(totalCount) ?? 0,
    };

    final tr = db.translations;
    final statusCount = countAll();
    final rows = await (db.selectOnly(tr).join([
      innerJoin(src, src.id.equalsExp(tr.sourceId)),
    ])
          ..addColumns([src.fileId, tr.status, statusCount])
          ..where(tr.locale.equals(locale))
          ..groupBy([src.fileId, tr.status]))
        .get();
    final byFile = <int, Map<String, int>>{};
    for (final r in rows) {
      final fid = r.read<int>(src.fileId)!;
      final st = r.read<String>(tr.status)!;
      (byFile[fid] ??= <String, int>{})[st] = r.read<int>(statusCount) ?? 0;
    }

    return [
      for (final f in files)
        () {
          final total = totalByFile[f.id] ?? 0;
          final counts = {for (final s in translationStatuses) s: 0}
            ..addAll(byFile[f.id] ?? {});
          final withRow = counts.values.fold<int>(0, (a, b) => a + b);
          counts['untranslated'] = counts['untranslated']! + total - withRow;
          return FileProgress(
            id: f.id,
            versionId: f.versionId,
            codec: f.codec,
            lba: f.lba,
            slotBytes: f.slotBytes,
            origBytes: f.origBytes,
            label: f.label,
            totalStrings: total,
            byStatus: counts,
          );
        }(),
    ];
  }

  /// Nombre de slots (alias compris) du fichier [fileId].
  Future<int> countSlots(int fileId) async {
    final c = countAll();
    final row = await (db.selectOnly(db.sourceStrings)
          ..addColumns([c])
          ..where(db.sourceStrings.fileId.equals(fileId)))
        .getSingle();
    return row.read(c) ?? 0;
  }

  /// Une page de slots de [fileId], triés par table puis slot.
  Future<List<SlotView>> slots(
    int fileId, {
    int offset = 0,
    int limit = 100,
  }) async {
    final src = db.sourceStrings;
    final target = db.alias(src, 'target');
    final tr = db.translations;
    final query = db.select(src).join([
      leftOuterJoin(target, target.id.equalsExp(src.aliasOf)),
      leftOuterJoin(
        tr,
        tr.sourceId.equalsExp(src.id) & tr.locale.equals(locale),
      ),
    ])
      ..where(src.fileId.equals(fileId))
      ..orderBy([OrderingTerm.asc(src.tableIdx), OrderingTerm.asc(src.slotIdx)])
      ..limit(limit, offset: offset);
    final rows = await query.get();
    return [
      for (final r in rows)
        SlotView(
          sourceId: r.readTable(src).id,
          fileId: fileId,
          tableIdx: r.readTable(src).tableIdx,
          slotIdx: r.readTable(src).slotIdx,
          sourceText: r.readTable(src).sourceText,
          aliasOfSlot: r.readTableOrNull(target)?.slotIdx,
          translation: _info(r.readTableOrNull(tr)),
        ),
    ];
  }

  /// Enregistre la traduction de la chaîne [sourceId].
  ///
  /// [expectedRevision] : `null` pour créer (conflit si une ligne existe
  /// déjà), sinon la révision que l'appelant a lue (conflit si elle a changé).
  /// Chaque écriture acceptée incrémente `revision`. Lève [TdbError] si la
  /// source n'existe pas, est un alias, si [status] est inconnu ou si [text]
  /// contient un NUL.
  Future<SaveResult> saveTranslation({
    required int sourceId,
    required String text,
    required String status,
    int? expectedRevision,
    String? authorId,
  }) async {
    if (!translationStatuses.contains(status)) {
      throw TdbError('unknown status "$status"');
    }
    if (text.contains('\u0000')) {
      throw const TdbError('translation contains NUL');
    }
    return db.transaction(() async {
      final source = await (db.select(db.sourceStrings)
            ..where((t) => t.id.equals(sourceId)))
          .getSingleOrNull();
      if (source == null) throw TdbError('unknown source string $sourceId');
      if (source.aliasOf != null) {
        throw TdbError(
          'source string $sourceId is an alias: translate its target',
          fileId: source.fileId,
        );
      }
      final tr = db.translations;
      final current = await (db.select(tr)
            ..where(
              (t) => t.sourceId.equals(sourceId) & t.locale.equals(locale),
            ))
          .getSingleOrNull();
      if (current == null) {
        if (expectedRevision != null) return const SaveConflict(null);
        final id = await db.into(tr).insert(
              TranslationsCompanion.insert(
                sourceId: sourceId,
                locale: locale,
                text_: text,
                status: status,
                authorId: Value(authorId),
              ),
            );
        await recordTranslationRevision(db, id);
        return SaveOk(_info(await _byId(id))!);
      }
      if (expectedRevision != current.revision) {
        return SaveConflict(_info(current));
      }
      await (db.update(tr)..where((t) => t.id.equals(current.id))).write(
        TranslationsCompanion(
          text_: Value(text),
          status: Value(status),
          revision: Value(current.revision + 1),
          authorId: Value(authorId),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await recordTranslationRevision(db, current.id);
      return SaveOk(_info(await _byId(current.id))!);
    });
  }

  /// Révisions de la traduction de [sourceId] (plus récente d'abord) ;
  /// vide si la chaîne n'a pas de traduction pour cette locale.
  Future<List<TranslationRevision>> history(int sourceId) async {
    final h = db.translationHistories;
    final tr = db.translations;
    final rows = await (db.select(h).join([
      innerJoin(tr, tr.id.equalsExp(h.translationId)),
    ])
          ..where(tr.sourceId.equals(sourceId) & tr.locale.equals(locale))
          ..orderBy([OrderingTerm.desc(h.revision)]))
        .get();
    return [
      for (final r in rows)
        TranslationRevision(
          revision: r.readTable(h).revision,
          text: r.readTable(h).text_,
          status: r.readTable(h).status,
          authorId: r.readTable(h).authorId,
          changedAt: r.readTable(h).changedAt,
        ),
    ];
  }

  Future<TranslationRow?> _byId(int id) =>
      (db.select(db.translations)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  TranslationInfo? _info(TranslationRow? r) => r == null
      ? null
      : TranslationInfo(
          id: r.id,
          text: r.text_,
          status: r.status,
          revision: r.revision,
          updatedAt: r.updatedAt,
          authorId: r.authorId,
        );
}
