// Budget de niveaux 1 et 2 d'un fichier reconstruit.
//
// Sources : docs/ARCHITECTURE.md §8.1 (emplacement), §8.2 (politiques
// `strict` / `slot`), §8.6 (rapport) ; AGENTS.md §4.4.

import 'package:mh_binary/mh_binary.dart';

import 'display_budget.dart';

/// Politique du niveau 2 (ARCHITECTURE.md §8.2).
enum BudgetPolicy {
  /// `taille_reconstruite <= taille_originale` (défaut, release).
  strict,

  /// `taille_reconstruite <= slot_bytes`, réservé aux fichiers validés en jeu.
  slot,
}

/// Résultat de l'évaluation du budget d'un fichier.
enum BudgetStatus {
  /// Niveaux 1 et 2 respectés.
  ok,

  /// Niveau 1 : taille alignée > `slotBytes`.
  slotOverflow,

  /// Niveau 2 : taille > limite de la politique.
  bufferOverflow,

  /// Politique `slot` demandée pour un fichier hors liste blanche.
  policyNotAllowed,
}

/// Rapport de budget d'un fichier (ARCHITECTURE.md §8.6 ; `warnings` : niveaux 3 et 4,
/// jamais bloquants).
final class BudgetReport {
  /// Voir les champs.
  const BudgetReport({
    required this.fileId,
    required this.origBytes,
    required this.rebuiltBytes,
    required this.slotBytes,
    required this.policy,
    required this.status,
    this.warnings = const [],
  });

  /// ID de fichier DATA.BIN (base 1).
  final int fileId;

  /// Taille originale en octets.
  final int origBytes;

  /// Taille reconstruite en octets (non alignée).
  final int rebuiltBytes;

  /// Taille de l'emplacement dans `DATA.BIN`.
  final int slotBytes;

  /// Politique demandée.
  final BudgetPolicy policy;

  /// Verdict.
  final BudgetStatus status;

  /// Avertissements d'affichage (niveaux 3 et 4) : informatifs, ils ne
  /// changent jamais [status].
  final List<DisplayWarning> warnings;

  /// Copie avec [warnings] remplacés.
  BudgetReport withWarnings(List<DisplayWarning> warnings) => BudgetReport(
        fileId: fileId,
        origBytes: origBytes,
        rebuiltBytes: rebuiltBytes,
        slotBytes: slotBytes,
        policy: policy,
        status: status,
        warnings: List.unmodifiable(warnings),
      );

  /// Taille reconstruite alignée sur le secteur.
  int get alignedBytes => alignUp(rebuiltBytes, sectorSize);

  /// Vrai si le build peut continuer.
  bool get isOk => status == BudgetStatus.ok;

  /// Lève [BudgetError] ou [PatchError] si le verdict est bloquant.
  void requireOk() {
    switch (status) {
      case BudgetStatus.ok:
        return;
      case BudgetStatus.slotOverflow:
        throw BudgetError(
          'aligned size $alignedBytes exceeds slot $slotBytes',
          level: BudgetLevel.slot,
          actualBytes: alignedBytes,
          limitBytes: slotBytes,
          fileId: fileId,
        );
      case BudgetStatus.bufferOverflow:
        final limit = policy == BudgetPolicy.strict ? origBytes : slotBytes;
        throw BudgetError(
          'size $rebuiltBytes exceeds $limit (policy ${policy.name})',
          level: BudgetLevel.buffer,
          actualBytes: rebuiltBytes,
          limitBytes: limit,
          fileId: fileId,
        );
      case BudgetStatus.policyNotAllowed:
        throw PatchError(
          'policy slot not allowed: file not in validated whitelist',
          fileId: fileId,
        );
    }
  }

  /// Représentation JSON du rapport (§8.6).
  Map<String, Object> toJson() => {
        'file_id': fileId,
        'orig_bytes': origBytes,
        'rebuilt_bytes': rebuiltBytes,
        'slot_bytes': slotBytes,
        'policy': policy.name,
        'status': status.name,
        'warnings': [for (final w in warnings) w.toJson()],
      };
}

/// Évalue les niveaux 1 et 2 pour un fichier reconstruit de [rebuiltBytes].
///
/// [slotAllowedFileIds] est la liste blanche de `config/validated_files.yaml`
/// (chargée par l'appelant). Sans effet pour [BudgetPolicy.strict].
BudgetReport evaluateFileBudget({
  required int fileId,
  required int origBytes,
  required int rebuiltBytes,
  required int slotBytes,
  BudgetPolicy policy = BudgetPolicy.strict,
  Set<int> slotAllowedFileIds = const {},
}) {
  BudgetReport report(BudgetStatus s) => BudgetReport(
        fileId: fileId,
        origBytes: origBytes,
        rebuiltBytes: rebuiltBytes,
        slotBytes: slotBytes,
        policy: policy,
        status: s,
      );

  if (policy == BudgetPolicy.slot && !slotAllowedFileIds.contains(fileId)) {
    return report(BudgetStatus.policyNotAllowed);
  }
  if (alignUp(rebuiltBytes, sectorSize) > slotBytes) {
    return report(BudgetStatus.slotOverflow);
  }
  final limit = policy == BudgetPolicy.strict ? origBytes : slotBytes;
  if (rebuiltBytes > limit) return report(BudgetStatus.bufferOverflow);
  return report(BudgetStatus.ok);
}
