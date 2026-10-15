/// Chiffrement de DATA.BIN, TOC, index, PatchFile.
library;

export 'src/data_bin_entry.dart';
export 'src/data_bin_index.dart';
export 'src/data_bin_toc.dart';
export 'src/data_cipher.dart';
export 'src/patch_apply.dart';
export 'src/patch_file.dart';

/// Nom du paquet (test de fumée).
const String mhDatabinPackageName = 'mh_databin';
