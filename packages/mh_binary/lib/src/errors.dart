/// Erreur de base du toolkit (AGENTS.md §7).
///
/// Sous-types : [FormatError], [CryptoError], [PatchError], [IsoError].
/// `BudgetError` sera ajouté avec `mh_budget`.
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
