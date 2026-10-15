import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';

import 'tables/builds.dart';
import 'tables/game_files.dart';
import 'tables/glossary_terms.dart';
import 'tables/source_strings.dart';
import 'tables/translation_histories.dart';
import 'tables/translations.dart';

part 'tdb_database.g.dart';

/// Base de traduction locale (docs/ARCHITECTURE.md §7).
///
/// Schéma v2 : `game_file`, `source_string`, `translation`, `build`,
/// `translation_history`, `glossary_term`. `comment` et `length_profile`
/// (§7.2) viendront avec les tâches qui en ont besoin.
@DriftDatabase(
  tables: [
    GameFiles,
    SourceStrings,
    Translations,
    Builds,
    TranslationHistories,
    GlossaryTerms,
  ],
)
class TdbDatabase extends _$TdbDatabase {
  /// Ouvre la base sur [executor].
  TdbDatabase(super.executor);

  /// Base en mémoire (tests).
  factory TdbDatabase.openInMemory() {
    _ensureSqlite();
    return TdbDatabase(NativeDatabase.memory());
  }

  /// Base dans le fichier [path] (créé si absent).
  factory TdbDatabase.openFile(String path) {
    _ensureSqlite();
    return TdbDatabase(NativeDatabase(File(path)));
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(translationHistories);
            await m.createTable(glossaryTerms);
            // Une révision d'historique par traduction existante.
            await customStatement(
              'INSERT INTO translation_history '
              '(translation_id, revision, text, status, author_id, changed_at) '
              'SELECT id, revision, text, status, author_id, updated_at '
              'FROM translation',
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Windows n'a pas `sqlite3.dll` : on utilise `winsqlite3.dll` (System32).
void _ensureSqlite() {
  if (Platform.isWindows) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open('winsqlite3.dll'),
    );
  }
}
