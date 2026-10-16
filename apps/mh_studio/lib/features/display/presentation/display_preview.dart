import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mh_budget/mh_budget.dart';

/// Échelle de l'aperçu : 1 pixel de la PSP = [previewScale] pixels d'écran.
const double previewScale = 2;

final RegExp _token = RegExp(
  r'~[A-Za-z][0-9A-Za-z]{2}|%[-+ 0#]*[0-9]*(?:\.[0-9]+)?[sdixXcfu]',
);

/// Aperçu à l'échelle d'un texte dans la boîte du profil.
///
/// La police du jeu étant à chasse fixe (docs/CALIBRATION.md §5), chaque
/// caractère occupe une cellule de la largeur du pas du contexte. La boîte
/// a la largeur `maxPx` du profil (trait vertical = limite) ; les caractères
/// qui la dépassent sont en rouge. Les codes `~Xnn` et marqueurs `%d` sont
/// des pastilles sans largeur (inconnue) et les caractères non mesurés sont
/// soulignés en orange.
class DisplayPreview extends StatelessWidget {
  const DisplayPreview({
    super.key,
    required this.text,
    required this.profile,
    required this.metrics,
  });

  final String text;
  final LengthProfile profile;
  final GlyphMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final font = profile.fontContext == null
        ? null
        : metrics.context(profile.fontContext!);
    if (font == null) {
      return const Text(
        'Aperçu indisponible : la police de ce profil n’est pas mesurée.',
        key: Key('display-preview-unavailable'),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final advance = font.advancePx.toDouble() * previewScale;
    final limitPx = profile.checksWidth ? profile.maxPx : null;
    final lines = text.split('\n');
    final measured = [for (final l in lines) metrics.measureLine(l, font.id).px]
        .fold(0, math.max);
    final boxPx = limitPx ?? math.max(measured, font.advancePx * 10);
    final boxWidth = boxPx * previewScale;

    Widget cell(String ch, {required bool over, required bool unknown}) =>
        Container(
          width: advance,
          height: advance * 1.7,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: over ? scheme.error.withValues(alpha: 0.35) : null,
            border: unknown
                ? const Border(
                    bottom: BorderSide(color: Colors.orange, width: 2),
                  )
                : null,
          ),
          child: Text(
            ch,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: advance / 0.6,
              height: 1,
              color: over ? scheme.error : null,
            ),
          ),
        );

    Widget chip(String t) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(t, style: const TextStyle(fontSize: 10)),
    );

    final rows = <Widget>[];
    var rowExtent = 0.0; // largeur de la plus large ligne, pastilles comprises
    for (final line in lines) {
      final cells = <Widget>[];
      var px = 0;
      var chips = 0;
      void run(String s) {
        for (final c in s.runes) {
          final known = metrics.knownChars.contains(c);
          final wide =
              metrics.wideAdvancePx != null &&
              !known &&
              metrics.measureLine(String.fromCharCode(c), font.id).glyphs > 0;
          final counted = known || wide;
          if (counted) {
            px += known ? font.advancePx : metrics.wideAdvancePx!;
          }
          cells.add(
            cell(
              String.fromCharCode(c),
              over: limitPx != null && px > limitPx,
              unknown: !counted,
            ),
          );
        }
      }

      var last = 0;
      for (final m in _token.allMatches(line)) {
        run(line.substring(last, m.start));
        cells.add(chip(m.group(0)!));
        chips++;
        last = m.end;
      }
      run(line.substring(last));
      rowExtent = math.max(
        rowExtent,
        (cells.length - chips) * advance + chips * 56,
      );
      rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
    }

    final width = math.max(boxWidth, rowExtent) + 10; // padding + border
    return SingleChildScrollView(
      key: const Key('display-preview'),
      scrollDirection: Axis.horizontal,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Stack(
          children: [
            if (limitPx != null)
              Positioned(
                key: const Key('display-limit'),
                left: boxWidth,
                top: 0,
                bottom: 0,
                child: Container(width: 1, color: scheme.primary),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ],
        ),
      ),
    );
  }
}
