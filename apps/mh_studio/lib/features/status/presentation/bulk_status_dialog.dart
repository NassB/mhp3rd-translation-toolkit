import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../application/bulk_status_actions.dart';

/// Statuts d'une traduction existante (`untranslated` n'a pas de ligne).
const _fromChoices = ['draft', 'translated', 'reviewed', 'locked'];

/// Dialogue « Changer le statut en masse » : choisit la portée (fichier ou une
/// table), les statuts de départ et le statut d'arrivée, affiche le nombre de
/// traductions concernées, puis applique. Le texte n'est jamais modifié.
class BulkStatusDialog extends ConsumerStatefulWidget {
  const BulkStatusDialog({
    super.key,
    required this.fileId,
    required this.tables,
    this.unsavedCount = 0,
  });

  final int fileId;

  /// Index des tables du fichier (non nulles).
  final List<int> tables;

  /// Modifications non enregistrées de l'éditeur : bloquent l'application
  /// (l'éditeur est rechargé après coup).
  final int unsavedCount;

  @override
  ConsumerState<BulkStatusDialog> createState() => _BulkStatusDialogState();
}

class _BulkStatusDialogState extends ConsumerState<BulkStatusDialog> {
  int? _table; // null = tout le fichier
  final Set<String> _from = {'draft'};
  String _to = 'translated';
  BulkStatusResult? _preview;
  String? _message;
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    if (_from.isEmpty) {
      setState(() {
        _preview = null;
        _message = 'Choisis au moins un statut de départ.';
      });
      return;
    }
    setState(() => _message = null);
    try {
      final r = await ref
          .read(bulkStatusActionsProvider)
          .run(
            fileId: widget.fileId,
            tableIdx: _table,
            from: _from,
            to: _to,
            dryRun: true,
          );
      if (mounted) setState(() => _preview = r);
    } on MhError catch (e) {
      if (mounted) {
        setState(() {
          _preview = null;
          _message = e.message;
        });
      }
    }
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(bulkStatusActionsProvider)
          .run(fileId: widget.fileId, tableIdx: _table, from: _from, to: _to);
      if (mounted) {
        setState(() {
          _done = true;
          _preview = null;
          _message = '${r.changed} traduction(s) passée(s) en « $_to ».';
        });
      }
    } on MhError catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final canApply =
        !_busy &&
        !_done &&
        widget.unsavedCount == 0 &&
        p != null &&
        p.changed > 0;
    return AlertDialog(
      title: const Text('Changer le statut en masse'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int?>(
              key: const Key('bulk-scope'),
              initialValue: _table,
              decoration: const InputDecoration(labelText: 'Portée'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tout le fichier'),
                ),
                for (final t in widget.tables)
                  DropdownMenuItem<int?>(value: t, child: Text('Table $t')),
              ],
              onChanged: _done
                  ? null
                  : (v) {
                      _table = v;
                      _refreshPreview();
                    },
            ),
            const SizedBox(height: 12),
            const Text('Statuts de départ'),
            Wrap(
              spacing: 8,
              children: [
                for (final s in _fromChoices)
                  FilterChip(
                    key: Key('bulk-from-$s'),
                    label: Text(s),
                    selected: _from.contains(s),
                    onSelected: _done
                        ? null
                        : (on) {
                            setState(() => on ? _from.add(s) : _from.remove(s));
                            _refreshPreview();
                          },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('bulk-to'),
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'Nouveau statut'),
              items: [
                for (final s in translationStatuses.where(
                  (s) => s != 'untranslated',
                ))
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: _done
                  ? null
                  : (v) {
                      _to = v!;
                      _refreshPreview();
                    },
            ),
            if (_from.contains('locked'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Les traductions verrouillées seront modifiées.',
                  key: const Key('bulk-locked-warning'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            if (p != null)
              Text(
                '${p.changed} traduction(s) concernée(s)'
                '${p.alreadyThere > 0 ? ', ${p.alreadyThere} déjà au statut' : ''}'
                '${p.skippedEmpty > 0 ? ', ${p.skippedEmpty} vide(s) ignorée(s)' : ''}.',
                key: const Key('bulk-preview'),
              ),
            if (widget.unsavedCount > 0)
              Text(
                '${widget.unsavedCount} modification(s) non enregistrée(s) : '
                'enregistre ou annule avant de continuer.',
                key: const Key('bulk-unsaved'),
              ),
            if (_message != null)
              Text(_message!, key: const Key('bulk-message')),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('bulk-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_done ? 'Fermer' : 'Annuler'),
        ),
        FilledButton(
          key: const Key('bulk-apply'),
          onPressed: canApply ? _apply : null,
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}
