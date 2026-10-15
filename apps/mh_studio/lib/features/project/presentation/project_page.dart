import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../application/project_providers.dart';

/// Projet ouvert : informations et contenu de la base (l'écran « liste des
/// fichiers » arrive en T29).
class ProjectPage extends ConsumerWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    final status = ref.watch(projectStatusProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projet'),
        actions: [
          TextButton(
            key: const Key('close-project'),
            onPressed: () {
              ref.read(projectPathProvider.notifier).close();
              context.go(Routes.home);
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
      body: project == null
          ? const Center(child: Text('Aucun projet ouvert'))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version : ${project.versionId}'),
                  Text('Locale : ${project.locale}'),
                  Text('ISO : ${project.isoPath}'),
                  const SizedBox(height: 16),
                  status.when(
                    data: (s) => s == null
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fichiers : ${s.files}'),
                              Text('Chaînes : ${s.strings}'),
                              for (final e in s.translationsByStatus.entries)
                                Text('  ${e.key} : ${e.value}'),
                            ],
                          ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Erreur : $e'),
                  ),
                ],
              ),
            ),
    );
  }
}
