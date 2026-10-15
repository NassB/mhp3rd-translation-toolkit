import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../application/dump_actions.dart';

/// Sens de l'échange avec un dossier mhtools.
enum DumpMode { import, export }

/// Dialogue d'import ou d'export d'un dossier mhtools pour un fichier. Le
/// chemin est saisi à la main (pas de sélecteur de dossier pour l'instant).
class DumpDialog extends ConsumerStatefulWidget {
  const DumpDialog({super.key, required this.mode, required this.fileId});

  final DumpMode mode;
  final int fileId;

  @override
  ConsumerState<DumpDialog> createState() => _DumpDialogState();
}

class _DumpDialogState extends ConsumerState<DumpDialog> {
  final _path = TextEditingController();
  String _status = 'draft';
  String? _error;
  String? _result;
  bool _busy = false;

  bool get _isImport => widget.mode == DumpMode.import;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final folder = _path.text.trim();
    if (folder.isEmpty) {
      setState(() => _error = 'Indiquez un dossier.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    final actions = ref.read(dumpActionsProvider.notifier);
    try {
      final String message;
      if (_isImport) {
        final n = await actions.importFolder(
          fileId: widget.fileId,
          folder: folder,
          status: _status,
        );
        message = n == 0
            ? 'Aucune traduction nouvelle ou modifiée.'
            : '$n traduction(s) créée(s) ou modifiée(s).';
      } else {
        final n = await actions.exportFolder(
          fileId: widget.fileId,
          folder: folder,
        );
        message = 'Dump écrit ($n table(s)).';
      }
      if (mounted) setState(() => _result = message);
    } on MhError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on FileSystemException catch (e) {
      if (mounted) {
        setState(() => _error = '${e.message}: ${e.path ?? folder}');
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = 'Texte invalide : ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      dumpActionsProvider,
    ); // garde le notifier en vie pendant le dialogue
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        _isImport ? 'Importer un dump mhtools' : 'Exporter au format mhtools',
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isImport
                  ? 'Dossier contenant filelist.txt et string_table_N.txt '
                        'du fichier #${widget.fileId}.'
                  : 'Dossier de destination (il ne doit pas déjà contenir '
                        'un dump) pour le fichier #${widget.fileId}.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dump-path'),
              controller: _path,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Dossier'),
            ),
            if (_isImport) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Statut des traductions : '),
                  DropdownButton<String>(
                    key: const Key('dump-status'),
                    value: _status,
                    items: [
                      for (final s in translationStatuses)
                        if (s != 'untranslated')
                          DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _status = v ?? _status),
                  ),
                ],
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('dump-error'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(_result!, key: const Key('dump-result')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('dump-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_result == null ? 'Annuler' : 'Fermer'),
        ),
        FilledButton(
          key: const Key('dump-run'),
          onPressed: _busy ? null : _run,
          child: Text(_isImport ? 'Importer' : 'Exporter'),
        ),
      ],
    );
  }
}
