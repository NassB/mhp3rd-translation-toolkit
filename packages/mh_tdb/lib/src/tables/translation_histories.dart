import 'package:drift/drift.dart';

// Importé pour que drift_dev résolve les tables des contraintes REFERENCES.
// ignore: unused_import
import 'translations.dart';

/// Table `translation_history` : une ligne par révision d'une traduction
/// (docs/ARCHITECTURE.md §7.2, « copie de chaque révision »).
@DataClassName('TranslationHistoryRow')
class TranslationHistories extends Table {
  @override
  String get tableName => 'translation_history';

  IntColumn get id => integer().autoIncrement()();

  // Contrainte SQL explicite : voir source_strings.dart.
  IntColumn get translationId =>
      integer().customConstraint('NOT NULL REFERENCES translation (id)')();
  IntColumn get revision => integer()();
  TextColumn get text_ => text().named('text')();
  TextColumn get status => text()();
  TextColumn get authorId => text().nullable()();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {translationId, revision},
      ];
}
