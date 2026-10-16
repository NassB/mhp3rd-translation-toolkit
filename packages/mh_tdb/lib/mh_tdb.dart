/// Base de traduction, repositories, synchronisation.
library;

export 'src/build_queries.dart';
export 'src/glossary_repository.dart';
export 'src/import_mhtools.dart';
export 'src/profile_repository.dart';
export 'src/status_queries.dart';
export 'src/tables/builds.dart';
export 'src/tables/game_files.dart';
export 'src/tables/glossary_terms.dart';
export 'src/tables/source_strings.dart';
export 'src/tables/translation_histories.dart';
export 'src/tables/translations.dart';
export 'src/tdb_database.dart';
export 'src/translation_memory.dart';
export 'src/translation_repository.dart';

/// Nom du paquet (test de fumée).
const String mhTdbPackageName = 'mh_tdb';
