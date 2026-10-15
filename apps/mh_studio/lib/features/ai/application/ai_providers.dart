import 'dart:io';

import 'package:mh_translate/mh_translate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../editor/application/file_editor.dart';
import '../../files/application/files_providers.dart';
import '../../glossary/application/glossary_providers.dart';
import '../../memory/application/memory_providers.dart';
import '../../project/application/project_providers.dart';

part 'ai_providers.g.dart';

/// Crée le client de chat ; remplaçable dans les tests.
typedef ChatClientFactory = ChatClient Function(Uri endpoint, String? apiKey);

/// Fabrique du client réel (API compatible OpenAI).
@riverpod
ChatClientFactory chatClientFactory(Ref ref) =>
    (endpoint, apiKey) =>
        OpenAiCompatibleClient(endpoint: endpoint, apiKey: apiKey);

/// Clé d'API éventuelle : **uniquement** la variable d'environnement
/// `MHTK_LLM_API_KEY` (jamais enregistrée dans le projet).
@riverpod
String? aiApiKey(Ref ref) => Platform.environment['MHTK_LLM_API_KEY'];

/// Lecture et écriture des réglages de pré-traduction du projet ouvert.
abstract interface class AiSettingsStore {
  AiSettings load();

  void save(AiSettings settings);
}

class _DiskStore implements AiSettingsStore {
  _DiskStore(this.dir);

  final String dir;

  @override
  AiSettings load() => AiSettings.load(dir);

  @override
  void save(AiSettings settings) => settings.save(dir);
}

/// Réglages du projet ouvert (`ai.json`, sans clé), `null` si aucun projet.
@riverpod
AiSettingsStore? aiSettingsStore(Ref ref) {
  final project = ref.watch(currentProjectProvider);
  return project == null ? null : _DiskStore(project.dir);
}

/// État d'une pré-traduction.
sealed class AiRunState {
  const AiRunState();
}

/// Rien en cours.
final class AiIdle extends AiRunState {
  const AiIdle();
}

/// En cours : [processed] chaînes sur [total].
final class AiRunning extends AiRunState {
  const AiRunning({required this.processed, required this.total});

  final int processed;
  final int total;
}

/// Terminée (même avec des chaînes en échec) : voir le rapport.
final class AiDone extends AiRunState {
  const AiDone(this.report);

  final PreTranslateReport report;
}

/// Impossible de démarrer ou erreur inattendue ; message sans texte du jeu.
final class AiFailed extends AiRunState {
  const AiFailed(this.message);

  final String message;
}

/// Lance et suit la pré-traduction d'un fichier (ou d'une chaîne). Le moteur
/// est asynchrone : l'interface reste réactive, sans isolate.
@riverpod
class AiRunner extends _$AiRunner {
  CancelToken? _cancel;

  @override
  AiRunState build() => const AiIdle();

  PreTranslateOptions _options({
    int? onlySourceId,
    bool includeDrafts = false,
  }) {
    final project = ref.read(currentProjectProvider);
    return PreTranslateOptions(
      // Une chaîne choisie à la main est retraduite même si c'est un brouillon.
      includeDrafts: includeDrafts || onlySourceId != null,
      onlySourceIds: onlySourceId == null ? null : {onlySourceId},
      prompt: PromptOptions(
        targetLanguage: languageNameOf(project?.locale ?? 'fr'),
      ),
    );
  }

  /// Ce qu'une exécution ferait, **sans rien envoyer**.
  Future<PreTranslatePlan> plan({
    required int fileId,
    int? onlySourceId,
    bool includeDrafts = false,
  }) {
    final repo = ref.read(translationRepositoryProvider);
    if (repo == null) throw StateError('no project open');
    return planPreTranslation(
      repo: repo,
      fileId: fileId,
      options: _options(
        onlySourceId: onlySourceId,
        includeDrafts: includeDrafts,
      ),
    );
  }

  /// Lance la pré-traduction. Les réglages (adresse, modèle) sont mémorisés
  /// dans le projet, sans clé. Un endpoint non local doit avoir été confirmé
  /// par l'appelant.
  Future<void> start({
    required int fileId,
    required String endpoint,
    required String model,
    int? onlySourceId,
    bool includeDrafts = false,
  }) async {
    final repo = ref.read(translationRepositoryProvider);
    final glossary = ref.read(glossaryRepositoryProvider);
    final uri = Uri.tryParse(endpoint.trim());
    if (repo == null || glossary == null) {
      state = const AiFailed('Aucun projet ouvert.');
      return;
    }
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      state = const AiFailed('Adresse du serveur invalide.');
      return;
    }
    final options = _options(
      onlySourceId: onlySourceId,
      includeDrafts: includeDrafts,
    );
    final cancel = _cancel = CancelToken();
    final client = ref.read(chatClientFactoryProvider)(
      uri,
      ref.read(aiApiKeyProvider),
    );
    state = const AiRunning(processed: 0, total: 0);
    try {
      final report = await preTranslateFile(
        repo: repo,
        glossary: glossary,
        client: client,
        model: model,
        fileId: fileId,
        options: options,
        cancel: cancel,
        onProgress: (p) {
          if (ref.mounted) {
            state = AiRunning(processed: p.processed, total: p.total);
          }
        },
      );
      if (!ref.mounted) return;
      ref
          .read(aiSettingsStoreProvider)
          ?.save(AiSettings(endpoint: endpoint.trim(), model: model));
      if (report.saved > 0 || report.shortened > 0) _refresh(fileId);
      state = AiDone(report);
    } on Object catch (e) {
      // Aucun texte du jeu : seul le type d'erreur est affiché.
      if (ref.mounted) state = AiFailed('Erreur : ${e.runtimeType}');
    } finally {
      if (client is OpenAiCompatibleClient) client.close();
    }
  }

  /// Demande l'arrêt entre deux lots ; ce qui est déjà enregistré est conservé.
  void cancel() => _cancel?.cancel();

  /// Revient à l'état initial.
  void reset() => state = const AiIdle();

  /// L'état enregistré a changé hors de l'éditeur (comme après un import).
  void _refresh(int fileId) {
    ref.read(budgetPatchesProvider.notifier).remove(fileId);
    ref
      ..invalidate(fileEditorProvider(fileId))
      ..invalidate(fileListProvider)
      ..invalidate(translationMemoryProvider)
      ..invalidate(fileBudgetsProvider);
  }
}
