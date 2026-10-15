import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../application/glossary_providers.dart';
import 'suggest_terms_dialog.dart';

/// Glossaire : terminologie du projet (termes obligatoires signalés par le
/// linter de l'éditeur).
class GlossaryPage extends ConsumerWidget {
  const GlossaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(glossaryListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glossaire'),
        actions: [
          IconButton(
            key: const Key('suggest-terms'),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Suggérer des termes',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SuggestTermsDialog(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-term'),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const _TermDialog(),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un terme'),
      ),
      body: terms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('Aucun terme dans le glossaire.'))
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => _TermTile(term: list[i]),
              ),
      ),
    );
  }
}

class _TermTile extends ConsumerWidget {
  const _TermTile({required this.term});

  final GlossaryTermRow term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      key: Key('term-${term.id}'),
      title: Text('${term.sourceTerm} → ${term.targetTerm}'),
      subtitle: term.note == null ? null : Text(term.note!),
      leading: term.mandatory
          ? const Tooltip(
              message: 'Terme obligatoire',
              child: Icon(Icons.priority_high, key: Key('mandatory-icon')),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('edit-${term.id}'),
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _TermDialog(term: term),
            ),
          ),
          IconButton(
            key: Key('delete-${term.id}'),
            icon: const Icon(Icons.delete),
            tooltip: 'Supprimer',
            onPressed: () =>
                ref.read(glossaryActionsProvider.notifier).delete(term.id),
          ),
        ],
      ),
    );
  }
}

class _TermDialog extends ConsumerStatefulWidget {
  const _TermDialog({this.term});

  /// Terme à modifier ; `null` pour un ajout.
  final GlossaryTermRow? term;

  @override
  ConsumerState<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends ConsumerState<_TermDialog> {
  late final _source = TextEditingController(text: widget.term?.sourceTerm);
  late final _target = TextEditingController(text: widget.term?.targetTerm);
  late final _note = TextEditingController(text: widget.term?.note);
  late bool _mandatory = widget.term?.mandatory ?? false;
  String? _error;

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final actions = ref.read(glossaryActionsProvider.notifier);
    try {
      final t = widget.term;
      if (t == null) {
        await actions.add(
          sourceTerm: _source.text,
          targetTerm: _target.text,
          note: _note.text,
          mandatory: _mandatory,
        );
      } else {
        await actions.update(
          t.id,
          targetTerm: _target.text,
          note: _note.text,
          mandatory: _mandatory,
        );
      }
    } on MhError catch (e) {
      setState(() => _error = e.message);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.term != null;
    return AlertDialog(
      title: Text(editing ? 'Modifier le terme' : 'Nouveau terme'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('term-source'),
              controller: _source,
              enabled: !editing,
              decoration: const InputDecoration(labelText: 'Terme source'),
            ),
            TextField(
              key: const Key('term-target'),
              controller: _target,
              decoration: const InputDecoration(labelText: 'Traduction'),
            ),
            TextField(
              key: const Key('term-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            SwitchListTile(
              key: const Key('term-mandatory'),
              title: const Text('Obligatoire'),
              value: _mandatory,
              onChanged: (v) => setState(() => _mandatory = v),
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('term-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('term-save'),
          onPressed: _save,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
