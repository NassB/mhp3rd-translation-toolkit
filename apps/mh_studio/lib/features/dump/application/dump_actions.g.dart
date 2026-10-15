// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dump_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Import et export de dossiers mhtools pour un fichier du projet (mêmes
/// fonctions que `mhtk import`, voir `mh_build/dump_folder.dart`).
///
/// Les erreurs ([MhError], [FileSystemException], [FormatException])
/// remontent à l'appelant pour affichage.

@ProviderFor(DumpActions)
final dumpActionsProvider = DumpActionsProvider._();

/// Import et export de dossiers mhtools pour un fichier du projet (mêmes
/// fonctions que `mhtk import`, voir `mh_build/dump_folder.dart`).
///
/// Les erreurs ([MhError], [FileSystemException], [FormatException])
/// remontent à l'appelant pour affichage.
final class DumpActionsProvider extends $NotifierProvider<DumpActions, void> {
  /// Import et export de dossiers mhtools pour un fichier du projet (mêmes
  /// fonctions que `mhtk import`, voir `mh_build/dump_folder.dart`).
  ///
  /// Les erreurs ([MhError], [FileSystemException], [FormatException])
  /// remontent à l'appelant pour affichage.
  DumpActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dumpActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dumpActionsHash();

  @$internal
  @override
  DumpActions create() => DumpActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$dumpActionsHash() => r'1fe98a7e29345a2c7cdae52d7f846e7f8c356e66';

/// Import et export de dossiers mhtools pour un fichier du projet (mêmes
/// fonctions que `mhtk import`, voir `mh_build/dump_folder.dart`).
///
/// Les erreurs ([MhError], [FileSystemException], [FormatException])
/// remontent à l'appelant pour affichage.

abstract class _$DumpActions extends $Notifier<void> {
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
