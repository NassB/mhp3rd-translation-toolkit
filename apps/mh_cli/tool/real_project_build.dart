// ignore_for_file: type=lint
// Contrôle local (T34) : runProjectBuild sur le projet réel, sortie dans out/.
import 'package:mh_build/mh_build.dart';

Future<void> main(List<String> a) async {
  final sw = Stopwatch()..start();
  final s = await runProjectBuild(
    Project.load(a[0]),
    config: defaultVersionsConfig,
    outPath: a[1],
  );
  print('${s.status} build=${s.buildId} rev=${s.tdbRevision} '
      'files=${s.files.map((f) => '${f.fileId}:${f.status.name}').join(',')} '
      'errors=${s.verifyErrors.length} in ${sw.elapsed.inSeconds}s');
}
