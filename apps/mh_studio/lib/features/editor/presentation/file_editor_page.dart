import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../../ai/presentation/pretranslate_dialog.dart';
import '../../dump/presentation/dump_dialog.dart';
import '../../files/presentation/budget_gauge.dart';
import '../../status/presentation/bulk_status_dialog.dart';
import '../application/file_editor.dart';
import '../application/file_editor_state.dart';
import 'slot_editor_panel.dart';

/// Éditeur d'un fichier : liste des chaînes à gauche, source | cible à droite,
/// jauge de budget du fichier en direct.
class FileEditorPage extends ConsumerStatefulWidget {
  const FileEditorPage({super.key, required this.fileId});

  final int fileId;

  @override
  ConsumerState<FileEditorPage> createState() => _FileEditorPageState();
}

class _FileEditorPageState extends ConsumerState<FileEditorPage> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(fileEditorProvider(widget.fileId));
    return Scaffold(
      appBar: AppBar(
        title: Text('Fichier #${widget.fileId}'),
        actions: [
          IconButton(
            key: const Key('pretranslate'),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Pré-traduire avec un modèle de langage',
            onPressed: () {
              final slots = editor.value?.slots ?? const [];
              final sel = slots.where((s) => s.sourceId == _selected);
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PreTranslateDialog(
                  fileId: widget.fileId,
                  selectedSourceId: sel.isNotEmpty && !sel.first.isAlias
                      ? _selected
                      : null,
                ),
              );
            },
          ),
          IconButton(
            key: const Key('bulk-status'),
            icon: const Icon(Icons.fact_check),
            tooltip: 'Changer le statut en masse',
            onPressed: () {
              final st = editor.value;
              if (st == null) return;
              showDialog<void>(
                context: context,
                builder: (_) => BulkStatusDialog(
                  fileId: widget.fileId,
                  tables: ({for (final s in st.slots) s.tableIdx}.toList()
                    ..sort()),
                  unsavedCount: st.drafts.length,
                ),
              );
            },
          ),
          IconButton(
            key: const Key('import-dump'),
            icon: const Icon(Icons.file_download),
            tooltip: 'Importer un dump mhtools',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  DumpDialog(mode: DumpMode.import, fileId: widget.fileId),
            ),
          ),
          IconButton(
            key: const Key('export-dump'),
            icon: const Icon(Icons.file_upload),
            tooltip: 'Exporter au format mhtools',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  DumpDialog(mode: DumpMode.export, fileId: widget.fileId),
            ),
          ),
        ],
      ),
      body: editor.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (s) => Column(
          children: [
            _GaugeBar(state: s),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 340,
                    child: _SlotList(
                      state: s,
                      selected: _selected,
                      onSelect: (id) => setState(() => _selected = id),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _selected == null
                        ? const Center(child: Text('Choisissez une chaîne.'))
                        : SlotEditorPanel(
                            key: ValueKey(_selected),
                            fileId: widget.fileId,
                            slot: s.slot(_selected!),
                            state: s,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeBar extends StatelessWidget {
  const _GaugeBar({required this.state});

  final FileEditorState state;

  @override
  Widget build(BuildContext context) {
    final b = state.liveBudget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: b != null
          ? BudgetGauge(key: const Key('live-gauge'), budget: b)
          : Text(
              state.budgetError == null
                  ? 'Jauge : calcul en cours…'
                  : 'Jauge indisponible : ${state.budgetError}',
              key: const Key('gauge-pending'),
            ),
    );
  }
}

class _SlotList extends StatelessWidget {
  const _SlotList({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final FileEditorState state;
  final int? selected;
  final void Function(int sourceId) onSelect;

  @override
  Widget build(BuildContext context) {
    final slots = state.slots;
    return ListView.builder(
      itemCount: slots.length,
      itemBuilder: (context, i) {
        final s = slots[i];
        return ListTile(
          key: Key('slot-${s.sourceId}'),
          dense: true,
          selected: s.sourceId == selected,
          title: Text(
            s.sourceText.replaceAll('\n', ' ↵ '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_subtitle(s)),
          trailing: state.isDirty(s.sourceId)
              ? const Icon(Icons.circle, size: 10, key: Key('dirty-dot'))
              : null,
          onTap: () => onSelect(s.sourceId),
        );
      },
    );
  }

  String _subtitle(SlotView s) {
    final where = '${s.tableIdx}.${s.slotIdx}';
    if (s.isAlias) return '$where · alias du slot ${s.aliasOfSlot}';
    final t = s.translation;
    final ai = (t?.authorId ?? '').startsWith('ai:') ? ' · IA' : '';
    return '$where · ${t?.status ?? 'untranslated'}$ai';
  }
}
