import 'package:mh_build/mh_build.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../editor/application/file_editor.dart';
import '../../files/application/files_providers.dart';
import '../../memory/application/memory_providers.dart';
import '../../project/application/project_providers.dart';

part 'dump_actions.g.dart';

/// Import et export de dossiers mhtools pour un fichier du projet (mêmes
/// fonctions que `mhtk import`, voir `mh_build/dump_folder.dart`).
///
/// Les erreurs ([MhError], [FileSystemException], [FormatException])
/// remontent à l'appelant pour affichage.
@riverpod
class DumpActions extends _$DumpActions {
  @override
  void build() {}

  /// Applique le dossier [folder] au fichier [fileId] ; retourne le nombre de
  /// traductions créées ou modifiées. Rafraîchit l'éditeur, la liste, la
  /// mémoire et les budgets (l'état enregistré a changé).
  Future<int> importFolder({
    required int fileId,
    required String folder,
    required String status,
  }) async {
    final project = ref.read(currentProjectProvider);
    final db = ref.read(tdbDatabaseProvider);
    if (project == null || db == null) throw StateError('no project open');
    final n = await importDumpFolder(
      db: db,
      project: project,
      config: ref.read(versionsConfigPathProvider),
      fileId: fileId,
      folder: folder,
      status: status,
    );
    if (n > 0) {
      ref.read(budgetPatchesProvider.notifier).remove(fileId);
      ref
        ..invalidate(fileEditorProvider(fileId))
        ..invalidate(fileListProvider)
        ..invalidate(translationMemoryProvider)
        ..invalidate(fileBudgetsProvider);
    }
    return n;
  }

  /// Écrit le dump du fichier [fileId] dans [folder] ; retourne le nombre de
  /// tables écrites.
  Future<int> exportFolder({
    required int fileId,
    required String folder,
  }) async {
    final project = ref.read(currentProjectProvider);
    final db = ref.read(tdbDatabaseProvider);
    if (project == null || db == null) throw StateError('no project open');
    return exportDumpFolder(
      db: db,
      project: project,
      config: ref.read(versionsConfigPathProvider),
      fileId: fileId,
      folder: folder,
    );
  }
}
