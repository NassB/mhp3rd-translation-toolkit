import 'package:flutter/material.dart';
import 'package:mh_formats/mh_formats.dart';

/// Message affiché pour un constat du linter.
String lintMessage(LintIssue i) => switch (i.kind) {
  LintKind.emptyTranslation => 'Traduction vide.',
  LintKind.newlineCount =>
    'Nombre de sauts de ligne différent de la source (${i.detail}).',
  LintKind.nulChar => 'Caractère NUL interdit.',
  LintKind.edgeWhitespace =>
    i.detail == 'leading'
        ? 'Espace en début de texte différente de la source.'
        : 'Espace en fin de texte différente de la source.',
  LintKind.mandatoryTerm => 'Terme obligatoire absent : « ${i.detail} ».',
  LintKind.suggestedTerm => 'Terme du glossaire absent : « ${i.detail} ».',
  LintKind.frenchSpacing => 'Espace insécable attendue avant « ${i.detail} ».',
};

/// Liste des constats du linter pour la chaîne en cours d'édition.
class LintList extends StatelessWidget {
  const LintList({super.key, required this.issues});

  final List<LintIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('lint-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in issues)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (i.severity) {
                    LintSeverity.error => Icons.error,
                    LintSeverity.warning => Icons.warning_amber,
                    LintSeverity.info => Icons.info_outline,
                  },
                  size: 16,
                  color: switch (i.severity) {
                    LintSeverity.error => scheme.error,
                    LintSeverity.warning => Colors.amber,
                    LintSeverity.info => scheme.outline,
                  },
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(lintMessage(i))),
              ],
            ),
          ),
      ],
    );
  }
}
