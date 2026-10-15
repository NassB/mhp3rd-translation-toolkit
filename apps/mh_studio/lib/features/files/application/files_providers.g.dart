// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Registre des versions du jeu (relatif au dossier de travail par défaut ;
/// surchargeable, à terme depuis des réglages).

@ProviderFor(versionsConfigPath)
final versionsConfigPathProvider = VersionsConfigPathProvider._();

/// Registre des versions du jeu (relatif au dossier de travail par défaut ;
/// surchargeable, à terme depuis des réglages).

final class VersionsConfigPathProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// Registre des versions du jeu (relatif au dossier de travail par défaut ;
  /// surchargeable, à terme depuis des réglages).
  VersionsConfigPathProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'versionsConfigPathProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$versionsConfigPathHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return versionsConfigPath(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$versionsConfigPathHash() =>
    r'851903c2c2b276b59b443340fce532094718f03b';

/// Accès aux fichiers et traductions du projet ouvert.

@ProviderFor(translationRepository)
final translationRepositoryProvider = TranslationRepositoryProvider._();

/// Accès aux fichiers et traductions du projet ouvert.

final class TranslationRepositoryProvider
    extends
        $FunctionalProvider<
          TranslationRepository?,
          TranslationRepository?,
          TranslationRepository?
        >
    with $Provider<TranslationRepository?> {
  /// Accès aux fichiers et traductions du projet ouvert.
  TranslationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translationRepositoryHash();

  @$internal
  @override
  $ProviderElement<TranslationRepository?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TranslationRepository? create(Ref ref) {
    return translationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TranslationRepository? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TranslationRepository?>(value),
    );
  }
}

String _$translationRepositoryHash() =>
    r'88f2b760b0143cbd3e9f53fed550e966727d7368';

/// Fichiers importés avec leur avancement.

@ProviderFor(fileList)
final fileListProvider = FileListProvider._();

/// Fichiers importés avec leur avancement.

final class FileListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<FileProgress>>,
          List<FileProgress>,
          FutureOr<List<FileProgress>>
        >
    with
        $FutureModifier<List<FileProgress>>,
        $FutureProvider<List<FileProgress>> {
  /// Fichiers importés avec leur avancement.
  FileListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileListHash();

  @$internal
  @override
  $FutureProviderElement<List<FileProgress>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<FileProgress>> create(Ref ref) {
    return fileList(ref);
  }
}

String _$fileListHash() => r'98c4d222100645302dc1a73b58b88c649a48b43f';

/// Budget courant de chaque fichier (jauges). Lit l'ISO et `DATA.BIN` : le
/// calcul tourne dans un isolate pour ne pas figer l'interface. Erreur (ISO ou
/// registre introuvable…) : les jauges sont indisponibles, la liste reste
/// affichée.

@ProviderFor(fileBudgets)
final fileBudgetsProvider = FileBudgetsProvider._();

/// Budget courant de chaque fichier (jauges). Lit l'ISO et `DATA.BIN` : le
/// calcul tourne dans un isolate pour ne pas figer l'interface. Erreur (ISO ou
/// registre introuvable…) : les jauges sont indisponibles, la liste reste
/// affichée.

final class FileBudgetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, FileBudget>>,
          Map<int, FileBudget>,
          FutureOr<Map<int, FileBudget>>
        >
    with
        $FutureModifier<Map<int, FileBudget>>,
        $FutureProvider<Map<int, FileBudget>> {
  /// Budget courant de chaque fichier (jauges). Lit l'ISO et `DATA.BIN` : le
  /// calcul tourne dans un isolate pour ne pas figer l'interface. Erreur (ISO ou
  /// registre introuvable…) : les jauges sont indisponibles, la liste reste
  /// affichée.
  FileBudgetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileBudgetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileBudgetsHash();

  @$internal
  @override
  $FutureProviderElement<Map<int, FileBudget>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, FileBudget>> create(Ref ref) {
    return fileBudgets(ref);
  }
}

String _$fileBudgetsHash() => r'717b69fd092d293d272f8341da5799b1c2f26c4c';
