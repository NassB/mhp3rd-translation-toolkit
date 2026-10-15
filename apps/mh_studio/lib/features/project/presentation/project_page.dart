import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../files/presentation/file_list_view.dart';
import '../application/project_providers.dart';

/// Projet ouvert : informations et liste des fichiers.
class ProjectPage extends ConsumerWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          project == null
              ? 'Projet'
              : 'Projet · ${project.versionId} · ${project.locale}',
        ),
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
          : const FileListView(),
    );
  }
}
