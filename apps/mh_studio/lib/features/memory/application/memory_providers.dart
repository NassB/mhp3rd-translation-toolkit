import 'package:mh_tdb/mh_tdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../project/application/project_providers.dart';

part 'memory_providers.g.dart';

/// Mémoire de traduction du projet ouvert (traductions `translated` ou plus).
/// Rechargée par l'éditeur après chaque enregistrement.
@riverpod
Future<TranslationMemory?> translationMemory(Ref ref) async {
  final project = ref.watch(currentProjectProvider);
  final db = ref.watch(tdbDatabaseProvider);
  if (project == null || db == null) return null;
  return TranslationMemory.load(db, locale: project.locale);
}
