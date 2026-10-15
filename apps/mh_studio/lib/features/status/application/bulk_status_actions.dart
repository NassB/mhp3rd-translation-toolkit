import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../../editor/application/file_editor.dart';
import '../../files/application/files_providers.dart';
import '../../memory/application/memory_providers.dart';

/// Changement de statut en masse (`TranslationRepository.bulkSetStatus`).
/// Les erreurs ([MhError]) remontent à l'appelant pour affichage.
class BulkStatusActions {
  BulkStatusActions(this._ref);

  final Ref _ref;

  /// Compte ou applique le changement. Après une application qui a changé
  /// quelque chose, l'éditeur, la liste et la mémoire sont rechargés.
  Future<BulkStatusResult> run({
    required int fileId,
    int? tableIdx,
    required Set<String> from,
    required String to,
    bool dryRun = false,
  }) async {
    final repo = _ref.read(translationRepositoryProvider);
    if (repo == null) throw StateError('no project open');
    final r = await repo.bulkSetStatus(
      fileId: fileId,
      tableIdx: tableIdx,
      from: from,
      to: to,
      dryRun: dryRun,
    );
    if (!dryRun && r.changed > 0) {
      _ref
        ..invalidate(fileEditorProvider(fileId))
        ..invalidate(fileListProvider)
        ..invalidate(translationMemoryProvider);
    }
    return r;
  }
}

/// Actions de changement de statut en masse.
final bulkStatusActionsProvider = Provider<BulkStatusActions>(
  BulkStatusActions.new,
);
