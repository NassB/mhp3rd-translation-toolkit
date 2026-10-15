// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fabrique du client réel (API compatible OpenAI).

@ProviderFor(chatClientFactory)
final chatClientFactoryProvider = ChatClientFactoryProvider._();

/// Fabrique du client réel (API compatible OpenAI).

final class ChatClientFactoryProvider
    extends
        $FunctionalProvider<
          ChatClientFactory,
          ChatClientFactory,
          ChatClientFactory
        >
    with $Provider<ChatClientFactory> {
  /// Fabrique du client réel (API compatible OpenAI).
  ChatClientFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatClientFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatClientFactoryHash();

  @$internal
  @override
  $ProviderElement<ChatClientFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChatClientFactory create(Ref ref) {
    return chatClientFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatClientFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatClientFactory>(value),
    );
  }
}

String _$chatClientFactoryHash() => r'e84d4ab0add169eb270ae2d529046aa88bef0524';

/// Clé d'API éventuelle : **uniquement** la variable d'environnement
/// `MHTK_LLM_API_KEY` (jamais enregistrée dans le projet).

@ProviderFor(aiApiKey)
final aiApiKeyProvider = AiApiKeyProvider._();

/// Clé d'API éventuelle : **uniquement** la variable d'environnement
/// `MHTK_LLM_API_KEY` (jamais enregistrée dans le projet).

final class AiApiKeyProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Clé d'API éventuelle : **uniquement** la variable d'environnement
  /// `MHTK_LLM_API_KEY` (jamais enregistrée dans le projet).
  AiApiKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiApiKeyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiApiKeyHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return aiApiKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$aiApiKeyHash() => r'431456fd49a4780e6aa7a4c89b7d7832a7f33bf9';

/// Réglages du projet ouvert (`ai.json`, sans clé), `null` si aucun projet.

@ProviderFor(aiSettingsStore)
final aiSettingsStoreProvider = AiSettingsStoreProvider._();

/// Réglages du projet ouvert (`ai.json`, sans clé), `null` si aucun projet.

final class AiSettingsStoreProvider
    extends
        $FunctionalProvider<
          AiSettingsStore?,
          AiSettingsStore?,
          AiSettingsStore?
        >
    with $Provider<AiSettingsStore?> {
  /// Réglages du projet ouvert (`ai.json`, sans clé), `null` si aucun projet.
  AiSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiSettingsStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<AiSettingsStore?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiSettingsStore? create(Ref ref) {
    return aiSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiSettingsStore? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiSettingsStore?>(value),
    );
  }
}

String _$aiSettingsStoreHash() => r'573d9908f1614cac031d5d39638f69de31ebe5a2';

/// Lance et suit la pré-traduction d'un fichier (ou d'une chaîne). Le moteur
/// est asynchrone : l'interface reste réactive, sans isolate.

@ProviderFor(AiRunner)
final aiRunnerProvider = AiRunnerProvider._();

/// Lance et suit la pré-traduction d'un fichier (ou d'une chaîne). Le moteur
/// est asynchrone : l'interface reste réactive, sans isolate.
final class AiRunnerProvider extends $NotifierProvider<AiRunner, AiRunState> {
  /// Lance et suit la pré-traduction d'un fichier (ou d'une chaîne). Le moteur
  /// est asynchrone : l'interface reste réactive, sans isolate.
  AiRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiRunnerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiRunnerHash();

  @$internal
  @override
  AiRunner create() => AiRunner();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiRunState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiRunState>(value),
    );
  }
}

String _$aiRunnerHash() => r'968b5d2ed636b18da5d166b30c66f314cd51eada';

/// Lance et suit la pré-traduction d'un fichier (ou d'une chaîne). Le moteur
/// est asynchrone : l'interface reste réactive, sans isolate.

abstract class _$AiRunner extends $Notifier<AiRunState> {
  AiRunState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AiRunState, AiRunState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiRunState, AiRunState>,
              AiRunState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
