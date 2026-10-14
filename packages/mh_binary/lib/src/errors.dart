/// Erreur de base du toolkit (AGENTS.md §7).
///
/// T3 ajoutera `CryptoError`, `PatchError`, `IsoError` ; seul `FormatError`
/// existe pour l'instant car `ByteReader` en a besoin.
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
