import 'package:flutter/material.dart';
import 'package:mh_build/mh_build.dart';

/// Niveau d'une jauge de budget.
enum GaugeLevel {
  /// Politique `strict` respectée.
  ok('strict'),

  /// Entre dans l'emplacement mais dépasse la taille d'origine.
  slotOnly('slot seulement'),

  /// Dépasse l'emplacement : build bloqué.
  over('dépassé');

  const GaugeLevel(this.label);

  /// Libellé affiché.
  final String label;
}

/// Niveau de [budget] (calculé par `mh_build`, jamais réimplémenté ici).
GaugeLevel gaugeLevel(FileBudget budget) {
  if (budget.fitsStrict) return GaugeLevel.ok;
  return budget.fitsSlot ? GaugeLevel.slotOnly : GaugeLevel.over;
}

/// Jauge « taille reconstruite / taille d'origine » d'un fichier.
class BudgetGauge extends StatelessWidget {
  const BudgetGauge({super.key, required this.budget});

  /// Budget courant du fichier.
  final FileBudget budget;

  @override
  Widget build(BuildContext context) {
    final level = gaugeLevel(budget);
    final scheme = Theme.of(context).colorScheme;
    final color = switch (level) {
      GaugeLevel.ok => Colors.green,
      GaugeLevel.slotOnly => Colors.amber,
      GaugeLevel.over => scheme.error,
    };
    final fill = budget.origBytes == 0
        ? 0.0
        : (budget.rebuiltBytes / budget.origBytes).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: fill, color: color, minHeight: 6),
        const SizedBox(height: 2),
        Text(
          '${budget.rebuiltBytes} / ${budget.origBytes} o · '
          'marge ${budget.strictMarginBytes} o · ${level.label}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
