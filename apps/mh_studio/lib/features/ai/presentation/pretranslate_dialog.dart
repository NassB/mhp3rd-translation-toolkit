import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_translate/mh_translate.dart';

import '../../editor/application/file_editor.dart';
import '../application/ai_providers.dart';

/// Portée d'une pré-traduction.
enum AiScope {
  /// La chaîne sélectionnée (même si c'est déjà un brouillon).
  selection,

  /// Les chaînes du fichier encore sans traduction.
  fileNew,

  /// Idem, plus les brouillons existants.
  fileWithDrafts,
}

/// Dialogue « Pré-traduire » : adresse du serveur, modèle, portée, estimation,
/// confirmation pour un serveur distant, progression et annulation.
///
/// Les traductions arrivent toujours en `draft` (jamais sur une traduction
/// `translated` ou plus). Aucun texte du jeu n'est affiché.
class PreTranslateDialog extends ConsumerStatefulWidget {
  const PreTranslateDialog({
    super.key,
    required this.fileId,
    this.selectedSourceId,
  });

  final int fileId;

  /// Chaîne sélectionnée dans l'éditeur (non alias), ou `null`.
  final int? selectedSourceId;

  @override
  ConsumerState<PreTranslateDialog> createState() => _PreTranslateDialogState();
}

class _PreTranslateDialogState extends ConsumerState<PreTranslateDialog> {
  late final TextEditingController _endpoint;
  late final TextEditingController _model;
  late AiScope _scope;
  List<String>? _models;
  String? _modelsError;
  bool _loadingModels = false;
  PreTranslatePlan? _plan;
  bool _planning = false;
  bool _confirmRemote = false;
  bool _logText = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiSettingsStoreProvider)?.load() ?? const AiSettings();
    _endpoint = TextEditingController(text: s.endpoint);
    _model = TextEditingController(text: s.model ?? '');
    _scope = widget.selectedSourceId == null
        ? AiScope.fileNew
        : AiScope.selection;
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    super.dispose();
  }

  Uri? get _uri {
    final u = Uri.tryParse(_endpoint.text.trim());
    return (u == null || !u.hasScheme || u.host.isEmpty) ? null : u;
  }

  bool get _remote => _uri != null && !isLocalEndpoint(_uri!);

  int? get _only =>
      _scope == AiScope.selection ? widget.selectedSourceId : null;

  Future<void> _loadModels() async {
    final uri = _uri;
    if (uri == null) {
      setState(() => _modelsError = 'Adresse du serveur invalide.');
      return;
    }
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    final client = ref.read(chatClientFactoryProvider)(
      uri,
      ref.read(aiApiKeyProvider),
    );
    try {
      final ids = await client.listModels();
      if (!mounted) return;
      setState(() {
        _models = ids;
        if (!ids.contains(_model.text)) _model.text = '';
      });
    } on TranslateError catch (e) {
      if (mounted) setState(() => _modelsError = e.message);
    } finally {
      if (client is OpenAiCompatibleClient) client.close();
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _estimate() async {
    setState(() => _planning = true);
    try {
      final plan = await ref
          .read(aiRunnerProvider.notifier)
          .plan(
            fileId: widget.fileId,
            onlySourceId: _only,
            includeDrafts: _scope == AiScope.fileWithDrafts,
          );
      if (mounted) setState(() => _plan = plan);
    } on MhError catch (e) {
      if (mounted) setState(() => _modelsError = e.message);
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  void _run() {
    ref
        .read(aiRunnerProvider.notifier)
        .start(
          fileId: widget.fileId,
          endpoint: _endpoint.text,
          model: _model.text.trim(),
          onlySourceId: _only,
          includeDrafts: _scope == AiScope.fileWithDrafts,
          logText: _logText,
        );
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(aiRunnerProvider);
    final unsaved =
        ref.watch(fileEditorProvider(widget.fileId)).value?.drafts.length ?? 0;
    final running = run is AiRunning;
    final scheme = Theme.of(context).colorScheme;
    final canRun =
        !running &&
        unsaved == 0 &&
        _uri != null &&
        _model.text.trim().isNotEmpty &&
        (!_remote || _confirmRemote);

    return AlertDialog(
      title: const Text('Pré-traduire avec un modèle de langage'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Les traductions proposées sont enregistrées en brouillon '
                '(« draft ») et ne remplacent jamais une traduction '
                'translated, relue ou verrouillée. À relire avant de les '
                'valider.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('ai-endpoint'),
                controller: _endpoint,
                enabled: !running,
                onChanged: (_) => setState(() {
                  _models = null;
                  _plan = null;
                  _confirmRemote = false;
                }),
                decoration: const InputDecoration(
                  labelText: 'Adresse du serveur (API compatible OpenAI)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _models == null
                        ? TextField(
                            key: const Key('ai-model'),
                            controller: _model,
                            enabled: !running,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Modèle',
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            key: const Key('ai-model-menu'),
                            initialValue: _models!.contains(_model.text)
                                ? _model.text
                                : null,
                            items: [
                              for (final m in _models!)
                                DropdownMenuItem(value: m, child: Text(m)),
                            ],
                            onChanged: running
                                ? null
                                : (v) => setState(() => _model.text = v ?? ''),
                            decoration: const InputDecoration(
                              labelText: 'Modèle',
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    key: const Key('ai-load-models'),
                    onPressed: running || _loadingModels ? null : _loadModels,
                    child: Text(
                      _loadingModels ? 'Chargement…' : 'Charger les modèles',
                    ),
                  ),
                ],
              ),
              if (_modelsError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _modelsError!,
                    key: const Key('ai-error'),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              CheckboxListTile(
                key: const Key('ai-log-text'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _logText,
                onChanged: running
                    ? null
                    : (v) => setState(() => _logText = v ?? false),
                title: const Text(
                  'Inclure le texte du jeu dans le journal (fichier local, '
                  'à ne pas publier)',
                ),
              ),
              if (_remote) ...[
                const SizedBox(height: 12),
                Card(
                  key: const Key('ai-remote-warning'),
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serveur distant : ${_uri!.host}. Le texte du jeu '
                          'serait envoyé à un tiers, de façon irréversible.',
                        ),
                        CheckboxListTile(
                          key: const Key('ai-confirm-remote'),
                          contentPadding: EdgeInsets.zero,
                          value: _confirmRemote,
                          onChanged: running
                              ? null
                              : (v) =>
                                    setState(() => _confirmRemote = v ?? false),
                          title: const Text(
                            'Je comprends et j’accepte d’envoyer le texte du '
                            'jeu à ce serveur.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              RadioGroup<AiScope>(
                groupValue: _scope,
                onChanged: (v) {
                  if (running || v == null) return;
                  setState(() {
                    _scope = v;
                    _plan = null;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<AiScope>(
                      key: const Key('ai-scope-selection'),
                      dense: true,
                      enabled: widget.selectedSourceId != null && !running,
                      value: AiScope.selection,
                      title: const Text('La chaîne sélectionnée'),
                    ),
                    RadioListTile<AiScope>(
                      key: const Key('ai-scope-file'),
                      dense: true,
                      enabled: !running,
                      value: AiScope.fileNew,
                      title: const Text(
                        'Les chaînes du fichier sans traduction',
                      ),
                    ),
                    RadioListTile<AiScope>(
                      key: const Key('ai-scope-drafts'),
                      dense: true,
                      enabled: !running,
                      value: AiScope.fileWithDrafts,
                      title: const Text('… y compris les brouillons existants'),
                    ),
                  ],
                ),
              ),
              if (unsaved > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$unsaved modification(s) non enregistrée(s) dans '
                    'l’éditeur : enregistrez-les ou annulez-les d’abord.',
                    key: const Key('ai-unsaved'),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              if (_plan != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _plan!.candidates == 0
                        ? 'Rien à traduire (déjà traduit, vide ou sans '
                              'japonais).'
                        : '${_plan!.candidates} chaîne(s) en '
                              '${_plan!.batches} lot(s), ≈ '
                              '${_plan!.estimatedPromptTokens} jetons envoyés. '
                              'Marge d’octets du fichier : '
                              '${_plan!.budgetMarginBytes}.',
                    key: const Key('ai-plan'),
                  ),
                ),
              const SizedBox(height: 12),
              switch (run) {
                AiRunning(:final processed, :final total) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      key: const Key('ai-progress'),
                      value: total == 0 ? null : processed / total,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total == 0
                          ? 'Envoi en cours…'
                          : '$processed / $total chaîne(s) traitée(s)',
                    ),
                  ],
                ),
                AiDone(:final report, :final logPath) => _Summary(
                  report: report,
                  logPath: logPath,
                ),
                AiFailed(:final message) => Text(
                  message,
                  key: const Key('ai-failed'),
                  style: TextStyle(color: scheme.error),
                ),
                AiIdle() => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
      actions: [
        if (running)
          TextButton(
            key: const Key('ai-cancel'),
            onPressed: () => ref.read(aiRunnerProvider.notifier).cancel(),
            child: const Text('Annuler le traitement'),
          )
        else
          TextButton(
            key: const Key('ai-close'),
            onPressed: () {
              ref.read(aiRunnerProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            child: Text(run is AiDone ? 'Fermer' : 'Annuler'),
          ),
        OutlinedButton(
          key: const Key('ai-estimate'),
          onPressed: running || _planning ? null : _estimate,
          child: const Text('Estimer'),
        ),
        FilledButton(
          key: const Key('ai-run'),
          onPressed: canRun ? _run : null,
          child: const Text('Lancer'),
        ),
      ],
    );
  }
}

String _reasonLabel(FailureReason r) => switch (r) {
  FailureReason.missing => 'absente de la réponse du modèle',
  FailureReason.newlineCount => 'sauts de ligne différents de la source',
  FailureReason.controlCodes => 'codes ~Xnn différents de la source',
  FailureReason.nulChar => 'caractère NUL',
  FailureReason.invisibleChar => 'caractère invisible ou de contrôle',
  FailureReason.mandatoryTerm => 'terme obligatoire du glossaire absent',
  FailureReason.overBudget => 'trop longue (octets)',
};

class _Summary extends StatelessWidget {
  const _Summary({required this.report, this.logPath});

  final PreTranslateReport report;
  final String? logPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final byReason = <FailureReason, int>{};
    for (final f in report.failed) {
      for (final r in f.reasons) {
        byReason[r] = (byReason[r] ?? 0) + 1;
      }
    }
    final lines = <String>[
      '${report.saved} brouillon(s) enregistré(s), ${report.failed.length} '
          'refusé(s), ${report.conflicts} conflit(s).',
      if (report.shortened > 0)
        '${report.shortened} chaîne(s) raccourcie(s) pour tenir dans le fichier.',
      if (report.cancelled)
        'Annulé : ${report.unprocessed} chaîne(s) non traitée(s).',
    ];
    return Column(
      key: const Key('ai-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines) Text(l),
        if (byReason.isNotEmpty)
          Text(
            'Motifs des refus : '
            '${byReason.entries.map((e) => '${_reasonLabel(e.key)} (${e.value})').join(', ')}.',
            key: const Key('ai-reasons'),
          ),
        if (report.stoppedBy != null)
          Text(
            'Arrêté : ${report.stoppedBy!.message} '
            '(${report.unprocessed} chaîne(s) non traitée(s)).',
            key: const Key('ai-stopped'),
            style: TextStyle(color: scheme.error),
          ),
        if (!report.withinBudget)
          Text(
            'Le fichier dépasse sa taille d’origine de '
            '${report.overBudgetBytes} octet(s) : raccourcissez des '
            'brouillons avant de les valider.',
            key: const Key('ai-over-budget'),
            style: TextStyle(color: scheme.error),
          ),
        if (logPath != null)
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  'Journal : $logPath',
                  key: const Key('ai-log-path'),
                ),
              ),
              IconButton(
                key: const Key('ai-copy-log'),
                icon: const Icon(Icons.copy),
                tooltip: 'Copier le chemin du journal',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: logPath!)),
              ),
            ],
          ),
      ],
    );
  }
}
