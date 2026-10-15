import 'package:drift/drift.dart';

/// Table `build` (docs/ARCHITECTURE.md §7.2).
@DataClassName('BuildRow')
class Builds extends Table {
  @override
  String get tableName => 'build';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get isoMd5 => text()();
  IntColumn get tdbRevision => integer()();
  TextColumn get toolkitVersion => text()();
  TextColumn get profile => text()();
  TextColumn get status => text()();

  /// Rapport JSON sérialisé (docs/ARCHITECTURE.md §8.6).
  TextColumn get reportJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
