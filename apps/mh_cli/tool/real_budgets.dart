// ignore_for_file: type=lint
// Contrôle local : budgets de tous les fichiers du projet (T29).
import 'package:mh_build/mh_build.dart';

Future<void> main(List<String> a) async {
  final sw = Stopwatch()..start();
  final project = Project.load(a[0]);
  final r = await computeProjectBudgets(project, config: defaultVersionsConfig);
  for (final b in r.values) {
    print(
        'file ${b.fileId}: ${b.rebuiltBytes}/${b.origBytes} slot ${b.slotBytes} strict=${b.fitsStrict} slot=${b.fitsSlot}');
  }
  print('done in ${sw.elapsed.inSeconds}s');
}
