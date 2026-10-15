// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Mémoire de traduction du projet ouvert (traductions `translated` ou plus).
/// Rechargée par l'éditeur après chaque enregistrement.

@ProviderFor(translationMemory)
final translationMemoryProvider = TranslationMemoryProvider._();

/// Mémoire de traduction du projet ouvert (traductions `translated` ou plus).
/// Rechargée par l'éditeur après chaque enregistrement.

final class TranslationMemoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TranslationMemory?>,
          TranslationMemory?,
          FutureOr<TranslationMemory?>
        >
    with
        $FutureModifier<TranslationMemory?>,
        $FutureProvider<TranslationMemory?> {
  /// Mémoire de traduction du projet ouvert (traductions `translated` ou plus).
  /// Rechargée par l'éditeur après chaque enregistrement.
  TranslationMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'translationMemoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$translationMemoryHash();

  @$internal
  @override
  $FutureProviderElement<TranslationMemory?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TranslationMemory?> create(Ref ref) {
    return translationMemory(ref);
  }
}

String _$translationMemoryHash() => r'a5fee1a31c1337e147f3a1fc79960d47936c4e1b';
