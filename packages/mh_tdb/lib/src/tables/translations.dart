import 'package:drift/drift.dart';
// Importé pour que drift_dev résolve les tables des contraintes REFERENCES.
// ignore: unused_import
import 'source_strings.dart';

/// Statuts autorisés (docs/ARCHITECTURE.md §7.2, contrainte CHECK).
const List<String> translationStatuses = [
  'untranslated',
  'draft',
  'translated',
  'reviewed',
  'locked',
];

/// Table `translation` (docs/ARCHITECTURE.md §7.2).
@DataClassName('TranslationRow')
class Translations extends Table {
  @override
  String get tableName => 'translation';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceId =>
      integer().customConstraint('NOT NULL REFERENCES source_string (id)')();

  /// 'fr', 'en', ...
  TextColumn get locale => text()();
  TextColumn get text_ => text().named('text')();
  late final TextColumn status =
      text().check(status.isIn(translationStatuses))();
  IntColumn get revision => integer().withDefault(const Constant(1))();

  /// Identifiant d'auteur (UUID en texte), absent en mode local.
  TextColumn get authorId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Cache de `mh_budget`.
  IntColumn get budgetBytes => integer().nullable()();
  IntColumn get budgetPxMax => integer().nullable()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {sourceId, locale},
      ];
}
