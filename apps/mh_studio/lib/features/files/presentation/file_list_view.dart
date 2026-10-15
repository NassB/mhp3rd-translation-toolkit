import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../application/files_providers.dart';
import 'budget_gauge.dart';

/// Liste des fichiers du projet : ID, libellé, progression, jauge de budget.
class FileListView extends ConsumerWidget {
  const FileListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(fileListProvider);
    final budgets = ref.watch(fileBudgetsProvider);
    final patches = ref.watch(budgetPatchesProvider);
    return files.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Text('Aucun fichier importé (mhtk extract).'),
          );
        }
        return Column(
          children: [
            if (budgets.hasError)
              MaterialBanner(
                key: const Key('budget-unavailable'),
                content: Text('Jauges indisponibles : ${budgets.error}'),
                actions: const [SizedBox.shrink()],
              ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => _FileTile(
                  file: list[i],
                  budgets: budgets,
                  patch: patches[list[i].id],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.budgets, this.patch});

  final FileProgress file;
  final AsyncValue<Map<int, FileBudget>> budgets;
  final FileBudget? patch;

  @override
  Widget build(BuildContext context) {
    final done = file.doneStrings;
    final total = file.totalStrings;
    final b = patch ?? budgets.value?[file.id];
    return ListTile(
      key: Key('file-${file.id}'),
      title: Text('#${file.id} · ${file.label ?? file.codec}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: total == 0 ? 0 : done / total),
          Text('$done / $total traduites'),
          const SizedBox(height: 4),
          if (b != null)
            BudgetGauge(budget: b)
          else if (budgets.isLoading)
            const Text('Jauge : calcul en cours…'),
        ],
      ),
    );
  }
}
