import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_budget/mh_budget.dart' show measuredLatinChars;
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../../glossary/application/glossary_providers.dart';
import '../../memory/application/memory_providers.dart';
import '../application/file_editor.dart';
import '../application/file_editor_state.dart';
import 'lint_list.dart';
import 'tokenized_text.dart';

/// Caractères observés à l'écran (T36/T38) : les autres sont signalés.
final _lintOptions = LintOptions(displayableChars: measuredLatinChars());

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

  /// Remplace tout le texte de la traduction par [text] (suggestion).
  void _replaceAll(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _editor.setDraft(slot.sourceId, text: text);
  }

  /// Insère [term] à la position du curseur (ou remplace la sélection).
  void _insert(String term) {
    final v = _controller.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, term);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + term.length),
    );
    _editor.setDraft(slot.sourceId, text: text);
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

    final entries = [
      for (final t
          in ref.watch(glossaryListProvider).value ?? const <GlossaryTermRow>[])
        GlossaryEntry(
          sourceTerm: t.sourceTerm,
          targetTerm: t.targetTerm,
          mandatory: t.mandatory,
        ),
    ];
    final matches = matchGlossary(slot.sourceText, entries);
    // Pas de constat sur une chaîne que l'on n'a pas encore commencée.
    final showLint = dirty || slot.translation != null;
    final issues = showLint
        ? lintTranslation(
            source: slot.sourceText,
            target: _currentText,
            glossary: entries,
            options: _lintOptions,
          )
        : const <LintIssue>[];

    final suggestions = slot.isAlias
        ? const <TmMatch>[]
        : ref
                  .watch(translationMemoryProvider)
                  .value
                  ?.suggest(slot.sourceText, excludeSourceId: id) ??
              const <TmMatch>[];

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
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final g in matches)
                    ActionChip(
                      key: Key('glossary-${g.sourceTerm}'),
                      avatar: g.mandatory
                          ? const Icon(Icons.priority_high, size: 16)
                          : null,
                      label: Text('${g.sourceTerm} → ${g.targetTerm}'),
                      tooltip: 'Insérer « ${g.targetTerm} »',
                      onPressed: () => _insert(g.targetTerm),
                    ),
                ],
              ),
            ],
            if (showLint) ...[
              const SizedBox(height: 8),
              LintList(issues: issues),
            ],
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Mémoire de traduction', style: theme.textTheme.labelLarge),
              for (var i = 0; i < suggestions.length; i++)
                _SuggestionTile(
                  key: Key('tm-$i'),
                  match: suggestions[i],
                  onUse: () => _replaceAll(suggestions[i].targetText),
                ),
            ],
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

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({super.key, required this.match, required this.onUse});

  final TmMatch match;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final pct = (match.score * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pct %${match.exact ? ' · exacte' : ''} · '
                    'fichier ${match.fileId}, ${match.tableIdx}.${match.slotIdx}'
                    ' · ${match.status}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!match.exact) ...[
                    const SizedBox(height: 2),
                    TokenizedText(match.sourceText),
                  ],
                  const SizedBox(height: 2),
                  TokenizedText(match.targetText),
                ],
              ),
            ),
            TextButton(
              key: const Key('tm-use'),
              onPressed: onUse,
              child: const Text('Utiliser'),
            ),
          ],
        ),
      ),
    );
  }
}
