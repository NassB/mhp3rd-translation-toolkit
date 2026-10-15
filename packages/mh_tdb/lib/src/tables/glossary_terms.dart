import 'package:drift/drift.dart';

/// Table `glossary_term` (docs/ARCHITECTURE.md §7.2, §7.6).
///
/// Un terme source n'a qu'une traduction par locale (`UNIQUE (locale,
/// source_term)`) : choix de T27 pour garder une terminologie unique.
@DataClassName('GlossaryTermRow')
class GlossaryTerms extends Table {
  @override
  String get tableName => 'glossary_term';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get locale => text()();
  TextColumn get sourceTerm => text()();
  TextColumn get targetTerm => text()();
  TextColumn get note => text().nullable()();

  /// Terme obligatoire : le linter signale une traduction qui ne l'emploie pas.
  BoolColumn get mandatory => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {locale, sourceTerm},
      ];
}
