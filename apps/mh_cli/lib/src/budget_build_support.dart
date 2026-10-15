import 'package:mh_budget/mh_budget.dart';

/// Analyse `--clé valeur` pour les clés [known] ; `null` si un argument est
/// inconnu ou sans valeur.
Map<String, String>? parseFlags(List<String> args, Set<String> known) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--') ||
        !known.contains(a.substring(2)) ||
        i + 1 >= args.length) {
      return null;
    }
    out[a.substring(2)] = args[++i];
  }
  return out;
}

/// `strict` ou `slot`, sinon `null`.
BudgetPolicy? parsePolicy(String name) {
  for (final p in BudgetPolicy.values) {
    if (p.name == name) return p;
  }
  return null;
}
