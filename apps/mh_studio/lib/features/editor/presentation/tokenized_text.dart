import 'package:flutter/material.dart';

/// Texte du jeu avec les sauts de ligne rendus en pastilles « ↵ » non
/// éditables (aperçu en lecture seule).
class TokenizedText extends StatelessWidget {
  const TokenizedText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = text.split('\n');
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '↵',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ),
        );
      }
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
    }
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
