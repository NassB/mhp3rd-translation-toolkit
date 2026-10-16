import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mh_binary/mh_binary.dart';
import 'package:mh_budget/mh_budget.dart';
import 'package:mh_tdb/mh_tdb.dart';

import '../application/display_providers.dart';
import 'display_preview.dart';

/// Message en français d'un constat d'affichage.
String displayIssueMessage(DisplayIssue i) => switch (i.kind) {
  DisplayWarningKind.pxOverflow =>
    'Ligne ${(i.line ?? 0) + 1} : ${i.value} px pour ${i.max} px autorisés.',
  DisplayWarningKind.linesOverflow =>
    '${i.value} lignes pour ${i.max} autorisées.',
  DisplayWarningKind.unknownGlyph =>
    'Caractère « ${String.fromCharCode(i.value)} » (U+'
        '${i.value.toRadixString(16).toUpperCase().padLeft(4, '0')}) : '
        'largeur non mesurée en jeu.',
};

/// Profil de longueur de la chaîne, avertissements d'affichage et aperçu à
/// l'échelle. Les avertissements sont informatifs : ils ne bloquent ni
/// l'enregistrement ni le build.
class DisplayPanel extends ConsumerStatefulWidget {
  const DisplayPanel({
    super.key,
    required this.fileId,
    required this.slot,
    required this.text,
  });

  final int fileId;
  final SlotView slot;

  /// Traduction en cours (brouillon ou enregistrée).
  final String text;

  @override
  ConsumerState<DisplayPanel> createState() => _DisplayPanelState();
}

class _DisplayPanelState extends ConsumerState<DisplayPanel> {
  /// Profil choisi dans le menu ; `null` tant que l'utilisateur n'a rien
  /// choisi (on affiche alors le profil effectif).
  String? _picked;
  bool _touched = false;
  String? _error;

  Future<void> _assign(ProfileScope scope, String? id) async {
    setState(() => _error = null);
    try {
      await ref
          .read(profileActionsProvider)
          .assign(
            fileId: widget.fileId,
            scope: scope,
            profileId: id,
            tableIdx: widget.slot.tableIdx,
            sourceId: widget.slot.sourceId,
          );
    } on MhError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(displayConfigProvider);
    final check = config.check;
    if (check == null) {
      return Card(
        key: const Key('display-unavailable'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            config.error != null
                ? 'Profils de longueur invalides : ${config.error}'
                : 'Profils de longueur indisponibles '
                      '(config/profiles.yaml, config/font_metrics.yaml).',
          ),
        ),
      );
    }
    final assigned = ref
        .watch(fileProfilesProvider(widget.fileId))
        .value?[widget.slot.sourceId];
    final selected = _touched ? _picked : assigned;
    final profile = selected == null ? null : check.profiles[selected];
    final theme = Theme.of(context);

    final evaluation = profile == null || widget.text.isEmpty
        ? null
        : evaluateDisplay(widget.text, profile, check.metrics);

    return Card(
      key: const Key('display-panel'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Affichage', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String?>(
                  key: const Key('profile-menu'),
                  value: selected,
                  hint: const Text('Aucun profil'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Aucun profil'),
                    ),
                    for (final p in check.profiles.all)
                      DropdownMenuItem<String?>(value: p.id, child: Text(p.id)),
                  ],
                  onChanged: (v) => setState(() {
                    _touched = true;
                    _picked = v;
                  }),
                ),
                TextButton(
                  key: const Key('profile-apply-string'),
                  onPressed: () => _assign(ProfileScope.string, selected),
                  child: const Text('Cette chaîne'),
                ),
                TextButton(
                  key: const Key('profile-apply-table'),
                  onPressed: () => _assign(ProfileScope.table, selected),
                  child: Text('Toute la table ${widget.slot.tableIdx}'),
                ),
                TextButton(
                  key: const Key('profile-apply-file'),
                  onPressed: () => _assign(ProfileScope.file, selected),
                  child: const Text('Défaut du fichier'),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                key: const Key('profile-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (profile != null) ...[
              if (profile.description.isNotEmpty)
                Text(profile.description, style: theme.textTheme.bodySmall),
              Text(
                _limitsLabel(profile),
                key: const Key('profile-limits'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (profile != null && widget.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              DisplayPreview(
                text: widget.text,
                profile: profile,
                metrics: check.metrics,
              ),
            ],
            if (evaluation != null) ...[
              const SizedBox(height: 8),
              Text(
                '${evaluation.lineCount} ligne(s), largeur '
                '${evaluation.exact ? '' : '≥ '}${evaluation.maxPx} px',
                key: const Key('display-summary'),
              ),
              for (var i = 0; i < evaluation.issues.length; i++)
                Text(
                  displayIssueMessage(evaluation.issues[i]),
                  key: Key('display-issue-$i'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (!evaluation.exact)
                Text(
                  'Largeur minimale : le texte contient des codes ~Xnn, '
                  'des %d ou des caractères de largeur inconnue.',
                  key: const Key('display-inexact'),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _limitsLabel(LengthProfile p) {
    final width = p.checksWidth
        ? '${p.maxPx} px (${p.fontContext})'
        : 'largeur non mesurée';
    final lines = p.maxLines > 0
        ? '${p.maxLines} ligne(s)${p.paginated ? ', paginé (lignes non contrôlées)' : ''}'
        : 'lignes non mesurées';
    return 'Limites : $width ; $lines.';
  }
}
