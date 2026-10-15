// ignore_for_file: type=lint
// Exploration locale : écrit dans out/ un dump mhtools du fichier 17 dont le
// premier slot non vide est raccourci de moitié (test de bout en bout T22c).
// Usage : dart run apps/mh_cli/tool/make_demo_dump.dart <project> <outDir>
import 'dart:io';

import 'package:mh_cli/src/project.dart';
import 'package:mh_formats/mh_formats.dart';

Future<void> main(List<String> a) async {
  final project = Project.load(a[0]);
  final s = await IsoSession.open(project.isoPath, defaultVersionsConfig);
  try {
    final e = s.index.byId(17);
    final f = decodeStringTableA(s.readPlain(e), fileId: 17);
    final d = exportMhtoolsDump(f, name: '0017.bin', size: 0, fileId: 17);
    Directory(a[1]).createSync(recursive: true);
    File('${a[1]}/filelist.txt').writeAsStringSync(d.fileListText);
    for (var j = 0; j < d.tableTexts.length; j++) {
      var t = d.tableTexts[j];
      if (t == null) continue;
      if (j == 0) {
        final lines = t.split('\n');
        final k =
            lines.indexWhere((l) => l.length > 4 && l != '<EMPTY STRING>');
        lines[k] = lines[k].substring(0, lines[k].length ~/ 2);
        t = lines.join('\n');
      }
      File('${a[1]}/${mhtoolsTableFileName(j)}').writeAsStringSync(t);
    }
    print('dump written: ${d.tableTexts.length} tables');
  } finally {
    s.close();
  }
}
