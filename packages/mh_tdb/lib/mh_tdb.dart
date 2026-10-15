/// Base de traduction, repositories, synchronisation.
library;

export 'src/import_mhtools.dart';
export 'src/tables/builds.dart';
export 'src/tables/game_files.dart';
export 'src/tables/source_strings.dart';
export 'src/tables/translations.dart';
export 'src/tdb_database.dart';

/// Nom du paquet (test de fumée).
const String mhTdbPackageName = 'mh_tdb';
