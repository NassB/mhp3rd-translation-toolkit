import 'package:mh_tdb/mh_tdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../project/application/project_providers.dart';

part 'glossary_providers.g.dart';

/// Glossaire du projet ouvert (locale du projet).
@riverpod
GlossaryRepository? glossaryRepository(Ref ref) {
  final project = ref.watch(currentProjectProvider);
  final db = ref.watch(tdbDatabaseProvider);
  if (project == null || db == null) return null;
  return GlossaryRepository(db, locale: project.locale);
}

/// Termes du glossaire, triés par terme source.
@riverpod
Future<List<GlossaryTermRow>> glossaryList(Ref ref) async {
  final repo = ref.watch(glossaryRepositoryProvider);
  return repo == null ? const [] : repo.all();
}

/// Modifications du glossaire. Les erreurs ([MhError]) remontent à l'appelant
/// pour affichage ; la liste est rechargée après chaque succès.
@riverpod
class GlossaryActions extends _$GlossaryActions {
  @override
  void build() {}

  GlossaryRepository get _repo {
    final repo = ref.read(glossaryRepositoryProvider);
    if (repo == null) throw StateError('no project open');
    return repo;
  }

  Future<void> add({
    required String sourceTerm,
    required String targetTerm,
    String? note,
    bool mandatory = false,
  }) async {
    await _repo.add(
      sourceTerm: sourceTerm.trim(),
      targetTerm: targetTerm.trim(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      mandatory: mandatory,
    );
    ref.invalidate(glossaryListProvider);
  }

  Future<void> update(
    int id, {
    required String targetTerm,
    String? note,
    required bool mandatory,
  }) async {
    await _repo.update(
      id,
      targetTerm: targetTerm.trim(),
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
      mandatory: mandatory,
    );
    ref.invalidate(glossaryListProvider);
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    ref.invalidate(glossaryListProvider);
  }
}
