import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mh_binary/mh_binary.dart';

import '../../../app/router.dart';
import '../application/project_providers.dart';

/// Accueil : choix du dossier projet (créé par `mhtk init`).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    try {
      ref.read(projectPathProvider.notifier).open(_controller.text.trim());
    } on MhError catch (e) {
      setState(() => _error = e.message);
      return;
    }
    setState(() => _error = null);
    context.go(Routes.project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MHP3rd Studio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ouvrir un projet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dossier contenant project.json et tdb.sqlite '
                  '(créé par « mhtk init » puis « mhtk extract »).',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('project-path'),
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Dossier du projet',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _open(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('open-project'),
                  onPressed: _open,
                  child: const Text('Ouvrir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
