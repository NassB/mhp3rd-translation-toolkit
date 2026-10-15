/// Codecs de formats du jeu (string_table_a, puis quest, pac, gim, font).
library;

export 'src/mhtools_dump.dart';
export 'src/mhtools_text.dart'
    show applyTableLines, exportTableLines, joinLines, splitLines;
export 'src/string_table_a_decoder.dart';
export 'src/string_table_a_encoder.dart';
export 'src/string_table_file.dart';
export 'src/text_token.dart';
export 'src/translation_lint.dart';

/// Nom du paquet (test de fumée).
const String mhFormatsPackageName = 'mh_formats';
