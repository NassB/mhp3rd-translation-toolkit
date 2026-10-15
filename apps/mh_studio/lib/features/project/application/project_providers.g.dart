// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Dossier du projet ouvert (`null` : aucun).

@ProviderFor(ProjectPath)
final projectPathProvider = ProjectPathProvider._();

/// Dossier du projet ouvert (`null` : aucun).
final class ProjectPathProvider
    extends $NotifierProvider<ProjectPath, String?> {
  /// Dossier du projet ouvert (`null` : aucun).
  ProjectPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectPathProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectPathHash();

  @$internal
  @override
  ProjectPath create() => ProjectPath();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$projectPathHash() => r'd08b09905bd6164576a0052df354f0bc7ae8537c';

/// Dossier du projet ouvert (`null` : aucun).

abstract class _$ProjectPath extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Métadonnées du projet ouvert, `null` si aucun.

@ProviderFor(currentProject)
final currentProjectProvider = CurrentProjectProvider._();

/// Métadonnées du projet ouvert, `null` si aucun.

final class CurrentProjectProvider
    extends $FunctionalProvider<Project?, Project?, Project?>
    with $Provider<Project?> {
  /// Métadonnées du projet ouvert, `null` si aucun.
  CurrentProjectProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentProjectProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentProjectHash();

  @$internal
  @override
  $ProviderElement<Project?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Project? create(Ref ref) {
    return currentProject(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Project? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Project?>(value),
    );
  }
}

String _$currentProjectHash() => r'ea15247813aec93001516c4378ba128f3a1bc5c2';

/// Base de traduction du projet ouvert (fermée à la fermeture du projet).

@ProviderFor(tdbDatabase)
final tdbDatabaseProvider = TdbDatabaseProvider._();

/// Base de traduction du projet ouvert (fermée à la fermeture du projet).

final class TdbDatabaseProvider
    extends $FunctionalProvider<TdbDatabase?, TdbDatabase?, TdbDatabase?>
    with $Provider<TdbDatabase?> {
  /// Base de traduction du projet ouvert (fermée à la fermeture du projet).
  TdbDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tdbDatabaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tdbDatabaseHash();

  @$internal
  @override
  $ProviderElement<TdbDatabase?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TdbDatabase? create(Ref ref) {
    return tdbDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TdbDatabase? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TdbDatabase?>(value),
    );
  }
}

String _$tdbDatabaseHash() => r'93b45385b39b805e9c3727c1cd44225daddd64cf';

/// Synthèse du contenu de la base (fichiers, chaînes, statuts).

@ProviderFor(projectStatus)
final projectStatusProvider = ProjectStatusProvider._();

/// Synthèse du contenu de la base (fichiers, chaînes, statuts).

final class ProjectStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<TdbStatus?>,
          TdbStatus?,
          FutureOr<TdbStatus?>
        >
    with $FutureModifier<TdbStatus?>, $FutureProvider<TdbStatus?> {
  /// Synthèse du contenu de la base (fichiers, chaînes, statuts).
  ProjectStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectStatusProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectStatusHash();

  @$internal
  @override
  $FutureProviderElement<TdbStatus?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TdbStatus?> create(Ref ref) {
    return projectStatus(ref);
  }
}

String _$projectStatusHash() => r'4f642c6ea1094083625d197fc99e44ef468f824e';
