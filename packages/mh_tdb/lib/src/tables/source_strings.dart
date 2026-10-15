import 'package:drift/drift.dart';
// Importé pour que drift_dev résolve les tables des contraintes REFERENCES.
// ignore: unused_import
import 'game_files.dart';

/// Table `source_string` (docs/ARCHITECTURE.md §7.2).
@DataClassName('SourceStringRow')
class SourceStrings extends Table {
  @override
  String get tableName => 'source_string';

  IntColumn get id => integer().autoIncrement()();
  // drift_dev 2.31 ignore `references(...)` here ("should be a simple class name"),
  // d'où la contrainte SQL explicite.
  IntColumn get fileId =>
      integer().customConstraint('NOT NULL REFERENCES game_file (id)')();
  IntColumn get tableIdx => integer()();
  IntColumn get slotIdx => integer()();

  /// SHA-1 hexadécimal des octets d'origine.
  TextColumn get sourceHash => text()();

  /// Texte UTF-8 avec `\n` réel (rendu des jetons) ; base privée uniquement.
  TextColumn get sourceText => text()();

  /// Chaîne dont celle-ci est un alias (même offset dans le binaire).
  IntColumn get aliasOf =>
      integer().nullable().customConstraint('REFERENCES source_string (id)')();
  TextColumn get contextProfile => text().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {fileId, tableIdx, slotIdx},
      ];
}
