/// Erreur de base du toolkit (AGENTS.md §7).
///
/// Sous-types : [FormatError], [CryptoError], [PatchError], [IsoError],
/// [BudgetError], [TdbError].
abstract class MhError implements Exception {
  /// Crée une erreur avec son [message] et le contexte optionnel
  /// ([offset] dans le flux, [fileId] mhtools base 1).
  const MhError(this.message, {this.offset, this.fileId});

  /// Description lisible de l'erreur.
  final String message;

  /// Offset en octets où l'erreur est survenue, si connu.
  final int? offset;

  /// ID de fichier concerné, si connu.
  final int? fileId;

  @override
  String toString() {
    final ctx = <String>[
      if (fileId != null) 'file=$fileId',
      if (offset != null) 'offset=0x${offset!.toRadixString(16)}',
    ];
    final suffix = ctx.isEmpty ? '' : ' [${ctx.join(', ')}]';
    return '$runtimeType: $message$suffix';
  }
}

/// Données binaires mal formées ou lecture hors bornes.
final class FormatError extends MhError {
  /// Voir [MhError].
  const FormatError(super.message, {super.offset, super.fileId});
}

/// Échec de chiffrement ou de déchiffrement de `DATA.BIN`.
final class CryptoError extends MhError {
  /// Voir [MhError].
  const CryptoError(super.message, {super.offset, super.fileId});
}

/// Échec de construction ou d'application d'un patch `MHP3RD_DATA.BIN`.
final class PatchError extends MhError {
  /// Voir [MhError].
  const PatchError(super.message, {super.offset, super.fileId});
}

/// Image ISO 9660 invalide, inattendue ou opération interdite sur l'ISO.
final class IsoError extends MhError {
  /// Voir [MhError].
  const IsoError(super.message, {super.offset, super.fileId});
}

/// Niveau de contrainte de budget dépassé (ARCHITECTURE.md §8).
enum BudgetLevel {
  /// §8.1 : taille alignée supérieure à l'emplacement dans `DATA.BIN`.
  slot,

  /// §8.2 : taille supérieure à la limite de la politique (`strict`/`slot`).
  buffer,
}

/// Dépassement de budget bloquant (niveaux 1 et 2).
final class BudgetError extends MhError {
  /// [actualBytes] dépasse [limitBytes] au niveau [level].
  const BudgetError(
    super.message, {
    required this.level,
    required this.actualBytes,
    required this.limitBytes,
    super.fileId,
  });

  /// Niveau de contrainte violé.
  final BudgetLevel level;

  /// Taille mesurée en octets.
  final int actualBytes;

  /// Limite applicable en octets.
  final int limitBytes;
}

/// Opération invalide sur la base de traduction (données incohérentes,
/// import en double, statut inconnu).
final class TdbError extends MhError {
  /// Voir [MhError].
  const TdbError(super.message, {super.offset, super.fileId});
}
