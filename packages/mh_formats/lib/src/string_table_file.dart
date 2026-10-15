import 'dart:typed_data';

/// Une chaîne d'une table (octets bruts, sans le `\0` final).
///
/// Les jetons (texte + codes de contrôle) sont reportés à T14.
final class StringSlot {
  /// Voir les champs.
  StringSlot({required this.index, required Uint8List raw, this.aliasOf})
      : raw = Uint8List.fromList(raw);

  /// Position de l'offset dans la table (0-based).
  final int index;

  /// Octets d'origine, sans terminateur.
  final Uint8List raw;

  /// Index du premier slot partageant le même offset, sinon `null`.
  final int? aliasOf;
}

/// Une table de chaînes (`stringOffsets` + chaînes).
final class StringTable {
  /// Voir les champs.
  StringTable({
    required List<int> originalOffsets,
    required List<StringSlot> slots,
  })  : originalOffsets = List.unmodifiable(originalOffsets),
        slots = List.unmodifiable(slots);

  /// Offsets de chaînes d'origine, relatifs au début de la table.
  final List<int> originalOffsets;

  /// Un slot par offset, dans l'ordre.
  final List<StringSlot> slots;
}

/// Fichier `string_table_a` décodé (docs/FORMATS/string_table_a.md).
final class StringTableFile {
  /// Voir les champs.
  StringTableFile({
    required this.unknownHeader,
    required List<StringTable?> tables,
    required Uint8List endData,
  })  : tables = List.unmodifiable(tables),
        endData = Uint8List.fromList(endData);

  /// i32 à l'offset 0x04, sens inconnu, conservé tel quel.
  final int unknownHeader;

  /// `null` = table nulle (offset `-1`).
  final List<StringTable?> tables;

  /// Octets après la dernière table, conservés tels quels.
  final Uint8List endData;
}
