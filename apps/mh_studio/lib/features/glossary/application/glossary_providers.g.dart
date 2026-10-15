// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'glossary_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Glossaire du projet ouvert (locale du projet).

@ProviderFor(glossaryRepository)
final glossaryRepositoryProvider = GlossaryRepositoryProvider._();

/// Glossaire du projet ouvert (locale du projet).

final class GlossaryRepositoryProvider
    extends
        $FunctionalProvider<
          GlossaryRepository?,
          GlossaryRepository?,
          GlossaryRepository?
        >
    with $Provider<GlossaryRepository?> {
  /// Glossaire du projet ouvert (locale du projet).
  GlossaryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'glossaryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$glossaryRepositoryHash();

  @$internal
  @override
  $ProviderElement<GlossaryRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GlossaryRepository? create(Ref ref) {
    return glossaryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GlossaryRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GlossaryRepository?>(value),
    );
  }
}

String _$glossaryRepositoryHash() =>
    r'59ef9af49998f017d1e7ae5b9e1d8e71686859de';

/// Termes du glossaire, triés par terme source.

@ProviderFor(glossaryList)
final glossaryListProvider = GlossaryListProvider._();

/// Termes du glossaire, triés par terme source.

final class GlossaryListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GlossaryTermRow>>,
          List<GlossaryTermRow>,
          FutureOr<List<GlossaryTermRow>>
        >
    with
        $FutureModifier<List<GlossaryTermRow>>,
        $FutureProvider<List<GlossaryTermRow>> {
  /// Termes du glossaire, triés par terme source.
  GlossaryListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'glossaryListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$glossaryListHash();

  @$internal
  @override
  $FutureProviderElement<List<GlossaryTermRow>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GlossaryTermRow>> create(Ref ref) {
    return glossaryList(ref);
  }
}

String _$glossaryListHash() => r'7cbaf144f42f3851af74afa90df428450fa4e3bc';

/// Modifications du glossaire. Les erreurs ([MhError]) remontent à l'appelant
/// pour affichage ; la liste est rechargée après chaque succès.

@ProviderFor(GlossaryActions)
final glossaryActionsProvider = GlossaryActionsProvider._();

/// Modifications du glossaire. Les erreurs ([MhError]) remontent à l'appelant
/// pour affichage ; la liste est rechargée après chaque succès.
final class GlossaryActionsProvider
    extends $NotifierProvider<GlossaryActions, void> {
  /// Modifications du glossaire. Les erreurs ([MhError]) remontent à l'appelant
  /// pour affichage ; la liste est rechargée après chaque succès.
  GlossaryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'glossaryActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$glossaryActionsHash();

  @$internal
  @override
  GlossaryActions create() => GlossaryActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$glossaryActionsHash() => r'786b37805812fedb1a8a1c29f6adca4801107c0e';

/// Modifications du glossaire. Les erreurs ([MhError]) remontent à l'appelant
/// pour affichage ; la liste est rechargée après chaque succès.

abstract class _$GlossaryActions extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
