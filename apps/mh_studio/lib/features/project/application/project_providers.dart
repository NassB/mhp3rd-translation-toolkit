import 'dart:io';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_providers.g.dart';

/// Dossier du projet ouvert (`null` : aucun).
@Riverpod(keepAlive: true)
class ProjectPath extends _$ProjectPath {
  @override
  String? build() => null;

  /// Ouvre le projet de [path] : `project.json` lisible et `tdb.sqlite`
  /// présent. Lève [MhError] sinon, sans changer le projet courant.
  void open(String path) {
    final project = Project.load(path);
    if (!File(project.dbPath).existsSync()) {
      throw IsoError('missing $projectDbName in $path');
    }
    state = path;
  }

  /// Ferme le projet courant.
  void close() => state = null;
}

/// Métadonnées du projet ouvert, `null` si aucun.
@riverpod
Project? currentProject(Ref ref) {
  final path = ref.watch(projectPathProvider);
  return path == null ? null : Project.load(path);
}

/// Base de traduction du projet ouvert (fermée à la fermeture du projet).
@riverpod
TdbDatabase? tdbDatabase(Ref ref) {
  final project = ref.watch(currentProjectProvider);
  if (project == null) return null;
  final db = TdbDatabase.openFile(project.dbPath);
  ref.onDispose(db.close);
  return db;
}

/// Synthèse du contenu de la base (fichiers, chaînes, statuts).
@riverpod
Future<TdbStatus?> projectStatus(Ref ref) async {
  final project = ref.watch(currentProjectProvider);
  final db = ref.watch(tdbDatabaseProvider);
  if (project == null || db == null) return null;
  return tdbStatus(db, locale: project.locale);
}
