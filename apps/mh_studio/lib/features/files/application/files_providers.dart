import 'dart:isolate';

import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../project/application/project_providers.dart';

part 'files_providers.g.dart';

/// Registre des versions du jeu (relatif au dossier de travail par défaut ;
/// surchargeable, à terme depuis des réglages).
@riverpod
String versionsConfigPath(Ref ref) => defaultVersionsConfig;

/// Accès aux fichiers et traductions du projet ouvert.
@riverpod
TranslationRepository? translationRepository(Ref ref) {
  final project = ref.watch(currentProjectProvider);
  final db = ref.watch(tdbDatabaseProvider);
  if (project == null || db == null) return null;
  return TranslationRepository(db, locale: project.locale);
}

/// Fichiers importés avec leur avancement.
@riverpod
Future<List<FileProgress>> fileList(Ref ref) async {
  final repo = ref.watch(translationRepositoryProvider);
  return repo == null ? const [] : repo.listFiles();
}

/// Budget courant de chaque fichier (jauges). Conservé en vie (le calcul est long) ;
/// recalculé quand le projet change. Lit l'ISO et `DATA.BIN` : le
/// calcul tourne dans un isolate pour ne pas figer l'interface. Erreur (ISO ou
/// registre introuvable…) : les jauges sont indisponibles, la liste reste
/// affichée.
@Riverpod(keepAlive: true)
Future<Map<int, FileBudget>> fileBudgets(Ref ref) async {
  final project = ref.watch(currentProjectProvider);
  final config = ref.watch(versionsConfigPathProvider);
  if (project == null) return const {};
  return Isolate.run(() => computeProjectBudgets(project, config: config));
}

/// Budgets mis à jour par l'éditeur après un enregistrement : la liste des
/// fichiers les préfère au calcul initial (obsolète jusqu'au prochain calcul).
@Riverpod(keepAlive: true)
class BudgetPatches extends _$BudgetPatches {
  @override
  Map<int, FileBudget> build() {
    // Repart de zéro quand le projet change ou se ferme.
    ref.watch(currentProjectProvider);
    return const {};
  }

  void put(FileBudget budget) => state = {...state, budget.fileId: budget};
}
