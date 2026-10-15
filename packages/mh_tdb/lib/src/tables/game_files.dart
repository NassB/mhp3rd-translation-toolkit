import 'package:drift/drift.dart';

/// Table `game_file` (docs/ARCHITECTURE.md §7.2).
@DataClassName('GameFileRow')
class GameFiles extends Table {
  @override
  String get tableName => 'game_file';

  /// ID DATA.BIN (base 1).
  IntColumn get id => integer()();

  /// ULJM05800 / NPJB40001_HD.
  TextColumn get versionId => text()();
  TextColumn get codec => text()();
  IntColumn get lba => integer()();
  IntColumn get slotBytes => integer()();
  IntColumn get origBytes => integer()();
  TextColumn get label => text().nullable()();

  /// Profil de longueur par défaut.
  TextColumn get contextProfile => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
