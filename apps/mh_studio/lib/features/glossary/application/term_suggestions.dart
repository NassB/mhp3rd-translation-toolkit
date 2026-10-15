import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_translate/mh_translate.dart';

import '../../ai/application/ai_providers.dart';
import '../../files/application/files_providers.dart';
import 'glossary_providers.dart';

/// Analyse locale des sources du projet : termes candidats absents du
/// glossaire (aucun envoi réseau).
typedef TermScanner = Future<List<TermCandidate>> Function({int minCount});

/// Demande une traduction par terme au modèle (serveur **local** seulement,
/// vérifié par l'appelant). Résultat : terme source → traduction proposée.
typedef TermProposer = Future<Map<String, String>> Function({
  required String endpoint,
  required String model,
  required List<TermCandidate> candidates,
  bool Function()? isCancelled,
});

/// Analyse des sources ; `null` sans projet ouvert.
final termScannerProvider = Provider<TermScanner?>((ref) {
  final repo = ref.watch(translationRepositoryProvider);
  final glossary = ref.watch(glossaryRepositoryProvider);
  if (repo == null || glossary == null) return null;
  return ({int minCount = 3}) =>
      projectTermCandidates(repo: repo, glossary: glossary, minCount: minCount);
});

/// Propositions du modèle ; remplaçable dans les tests.
final termProposerProvider = Provider<TermProposer>((ref) {
  return ({
    required endpoint,
    required model,
    required candidates,
    isCancelled,
  }) async {
    final uri = Uri.parse(endpoint.trim());
    final client = ref.read(chatClientFactoryProvider)(
      uri,
      ref.read(aiApiKeyProvider),
    );
    try {
      return await proposeTermTranslations(
        client: client,
        model: model,
        candidates: candidates,
        isCancelled: isCancelled,
      );
    } finally {
      if (client is OpenAiCompatibleClient) client.close();
    }
  };
});
