import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_translate/mh_translate.dart';

import '../../ai/application/ai_providers.dart';
import '../application/glossary_providers.dart';
import '../application/term_suggestions.dart';

class _Row {
  _Row(this.candidate) : controller = TextEditingController();

  final TermCandidate candidate;
  final TextEditingController controller;
  bool selected = false;
}

/// Amorçage du glossaire : termes fréquents des sources (analyse locale) et
/// traductions proposées par le modèle. **Rien n'est ajouté sans que tu
/// coches le terme** ; seul un serveur local est accepté.
class SuggestTermsDialog extends ConsumerStatefulWidget {
  const SuggestTermsDialog({super.key});

  @override
  ConsumerState<SuggestTermsDialog> createState() => _SuggestTermsDialogState();
}

class _SuggestTermsDialogState extends ConsumerState<SuggestTermsDialog> {
  late final TextEditingController _endpoint;
  late final TextEditingController _model;
  List<_Row> _rows = const [];
  bool _scanned = false;
  bool _busy = false;
  bool _cancel = false;
  String? _message;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiSettingsStoreProvider)?.load() ?? const AiSettings();
    _endpoint = TextEditingController(text: s.endpoint);
    _model = TextEditingController(text: s.model ?? '');
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final scan = ref.read(termScannerProvider);
    if (scan == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final c = await scan();
      if (!mounted) return;
      for (final r in _rows) {
        r.controller.dispose();
      }
      setState(() {
        _rows = [for (final x in c) _Row(x)];
        _scanned = true;
      });
    } on MhError catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _propose() async {
    final uri = Uri.tryParse(_endpoint.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _message = 'Adresse du serveur invalide.');
      return;
    }
    if (!isLocalEndpoint(uri)) {
      setState(
        () => _message =
            'Seul un serveur local est accepté ici : le texte du jeu ne '
            'quitte pas cet ordinateur.',
      );
      return;
    }
    if (_model.text.trim().isEmpty) {
      setState(() => _message = 'Indique un modèle.');
      return;
    }
    final todo = [
      for (final r in _rows)
        if (r.controller.text.trim().isEmpty) r.candidate,
    ];
    setState(() {
      _busy = true;
      _cancel = false;
      _message = null;
    });
    try {
      final out = await ref.read(termProposerProvider)(
        endpoint: _endpoint.text,
        model: _model.text.trim(),
        candidates: todo,
        isCancelled: () => _cancel,
      );
      if (!mounted) return;
      setState(() {
        for (final r in _rows) {
          final p = out[r.candidate.term];
          if (p != null && r.controller.text.trim().isEmpty) {
            r.controller.text = p;
          }
        }
        _message = '${out.length} proposition(s) reçue(s) sur ${todo.length}.';
      });
    } on TranslateError catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addSelected() async {
    final actions = ref.read(glossaryActionsProvider.notifier);
    final kept = <_Row>[];
    var added = 0;
    String? error;
    for (final r in _rows) {
      if (!r.selected || r.controller.text.trim().isEmpty) {
        kept.add(r);
        continue;
      }
      try {
        await actions.add(
          sourceTerm: r.candidate.term,
          targetTerm: r.controller.text,
        );
        added++;
        r.controller.dispose();
      } on MhError catch (e) {
        kept.add(r);
        error = e.message;
      }
    }
    if (!mounted) return;
    setState(() {
      _rows = kept;
      _added += added;
      _message = error ?? '$added terme(s) ajouté(s).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectable = _rows
        .where((r) => r.selected && r.controller.text.trim().isNotEmpty)
        .length;
    return AlertDialog(
      title: const Text('Suggérer des termes'),
      content: SizedBox(
        width: 640,
        height: 520,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('suggest-endpoint'),
                    controller: _endpoint,
                    decoration: const InputDecoration(labelText: 'Serveur'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('suggest-model'),
                    controller: _model,
                    decoration: const InputDecoration(labelText: 'Modèle'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonal(
                  key: const Key('suggest-scan'),
                  onPressed: _busy ? null : _scan,
                  child: const Text('Analyser les sources'),
                ),
                FilledButton.tonal(
                  key: const Key('suggest-propose'),
                  onPressed: _busy || _rows.isEmpty ? null : _propose,
                  child: const Text('Proposer des traductions'),
                ),
                if (_busy) ...[
                  const SizedBox(width: 12),
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  TextButton(
                    key: const Key('suggest-cancel'),
                    onPressed: () => _cancel = true,
                    child: const Text('Arrêter'),
                  ),
                ],
              ],
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!, key: const Key('suggest-message')),
              ),
            const Divider(),
            Expanded(
              child: _rows.isEmpty
                  ? Center(
                      child: Text(
                        _scanned
                            ? 'Aucun terme candidat (ou tous déjà au glossaire).'
                            : "Lance l'analyse pour voir les termes fréquents.",
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return ListTile(
                          key: Key('cand-$i'),
                          dense: true,
                          leading: Checkbox(
                            key: Key('cand-check-$i'),
                            value: r.selected,
                            onChanged: (v) =>
                                setState(() => r.selected = v ?? false),
                          ),
                          title: Text(
                            '${r.candidate.term}  ×${r.candidate.count}',
                          ),
                          subtitle: TextField(
                            key: Key('cand-text-$i'),
                            controller: r.controller,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Traduction',
                              isDense: true,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('suggest-close'),
          onPressed: () => Navigator.of(context).pop(_added),
          child: const Text('Fermer'),
        ),
        FilledButton(
          key: const Key('suggest-add'),
          onPressed: selectable == 0 || _busy ? null : _addSelected,
          child: Text('Ajouter la sélection ($selectable)'),
        ),
      ],
    );
  }
}
