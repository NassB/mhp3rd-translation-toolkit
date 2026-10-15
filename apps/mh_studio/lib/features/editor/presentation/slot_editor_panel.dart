import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../application/file_editor.dart';
import '../application/file_editor_state.dart';
import 'tokenized_text.dart';

/// Panneau source | cible de la chaîne sélectionnée.
class SlotEditorPanel extends ConsumerStatefulWidget {
  const SlotEditorPanel({
    super.key,
    required this.fileId,
    required this.slot,
    required this.state,
  });

  final int fileId;
  final SlotView slot;
  final FileEditorState state;

  @override
  ConsumerState<SlotEditorPanel> createState() => _SlotEditorPanelState();
}

class _SlotEditorPanelState extends ConsumerState<SlotEditorPanel> {
  late final TextEditingController _controller;

  SlotView get slot => widget.slot;

  String get _currentText =>
      widget.state.drafts[slot.sourceId]?.text ?? slot.translation?.text ?? '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _currentText);
  }

  @override
  void didUpdateWidget(SlotEditorPanel old) {
    super.didUpdateWidget(old);
    // Texte modifié hors du champ (annulation, rechargement après conflit).
    if (_controller.text != _currentText) {
      _controller.value = TextEditingValue(
        text: _currentText,
        selection: TextSelection.collapsed(offset: _currentText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  FileEditor get _editor =>
      ref.read(fileEditorProvider(widget.fileId).notifier);

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final id = slot.sourceId;
    final dirty = s.isDirty(id);
    final saving = s.savingIds.contains(id);
    final conflict = s.conflicts.containsKey(id);
    final status = s.drafts[id]?.status ?? slot.translation?.status ?? 'draft';
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Table ${slot.tableIdx} · slot ${slot.slotIdx}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text('Source', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: TokenizedText(slot.sourceText),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (conflict)
            _ConflictBanner(fileId: widget.fileId, slot: slot, state: s),
          if (slot.isAlias)
            const Card(
              key: Key('alias-note'),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Cette chaîne partage celle d’un autre slot : '
                  'traduisez la chaîne cible.',
                ),
              ),
            )
          else ...[
            Text('Traduction', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextField(
              key: const Key('target-field'),
              controller: _controller,
              minLines: 3,
              maxLines: null,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              onChanged: (t) => _editor.setDraft(id, text: t),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TokenizedText(_currentText),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  key: const Key('status-menu'),
                  value: status,
                  items: [
                    for (final st in translationStatuses)
                      DropdownMenuItem(value: st, child: Text(st)),
                  ],
                  onChanged: (v) {
                    if (v != null) _editor.setDraft(id, status: v);
                  },
                ),
                TextButton(
                  key: const Key('discard-button'),
                  onPressed: dirty && !saving
                      ? () => _editor.discard(id)
                      : null,
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  key: const Key('save-button'),
                  onPressed: dirty && !saving ? () => _editor.save(id) : null,
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConflictBanner extends ConsumerWidget {
  const _ConflictBanner({
    required this.fileId,
    required this.slot,
    required this.state,
  });

  final int fileId;
  final SlotView slot;
  final FileEditorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theirs = state.conflicts[slot.sourceId];
    final editor = ref.read(fileEditorProvider(fileId).notifier);
    return Card(
      key: const Key('conflict-banner'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              theirs == null
                  ? 'Cette traduction a été supprimée ailleurs.'
                  : 'Modifiée ailleurs (révision ${theirs.revision}) :',
            ),
            if (theirs != null) ...[
              const SizedBox(height: 4),
              TokenizedText(theirs.text),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('conflict-reload'),
                  onPressed: () => editor.adoptConflict(slot.sourceId),
                  child: const Text('Recharger (perdre mon brouillon)'),
                ),
                OutlinedButton(
                  key: const Key('conflict-keep'),
                  onPressed: () => editor.keepDraftOverConflict(slot.sourceId),
                  child: const Text('Garder mon brouillon'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
