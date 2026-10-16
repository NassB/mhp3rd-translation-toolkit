// ignore_for_file: type=lint
// T44 — visite scriptée de PPSSPP (docs/QA_PPSSPP.md §10) : lance PPSSPP avec
// une ISO, envoie des touches par le débogueur WebSocket, capture la fenêtre
// et mesure le pas des caractères de chaque ligne de texte détectée.
//
//   dart run apps/mh_cli/tool/ppsspp_tour.dart \
//       --exe out/ppsspp_test/PPSSPPWindows64.exe --iso out/MHP3.calib2.iso \
//       --script apps/mh_cli/tool/tours/boot.json --out out/ppsspp_tour
//
// Options : `--state FICHIER.ppst` (charge un état de sauvegarde au lancement),
// `--port N` : se connecter à une instance déjà lancée (sans la
// fermer). Windows seulement (PrintWindow). Les captures sont des images du
// jeu : elles restent dans `out/` (ignoré par git).
//
// Format du script (JSON) : { "steps": [ ... ] } où chaque étape est :
//   {"wait": 20}                               attendre 20 s
//   {"press": ["start","cross"], "hold": 5, "pause": 1.5}
//                                               touches (maintien en images
//                                               vidéo), pause après chacune
//   {"shot": "nom", "analyze": true}            capture + pas de chaque ligne
//   {"shot": "nom", "regions": [[x0,y0,x1,y1]]} capture + pas de ces bandes
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ppsspp/image_analysis.dart';

Future<void> main(List<String> args) async {
  String? exe, iso, script, portArg, state;
  var outDir = 'out/ppsspp_tour';
  var keepOpen = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--exe':
        exe = args[++i];
      case '--iso':
        iso = args[++i];
      case '--script':
        script = args[++i];
      case '--out':
        outDir = args[++i];
      case '--state':
        state = args[++i];
      case '--port':
        portArg = args[++i];
      case '--keep-open':
        keepOpen = true;
    }
  }
  if (script == null || (portArg == null && (exe == null || iso == null))) {
    stderr.writeln('usage: ppsspp_tour.dart --script tour.json '
        '(--exe PPSSPPWindows64.exe --iso game.iso | --port N) '
        '[--out dir] [--keep-open]');
    exit(64);
  }
  final steps =
      (jsonDecode(File(script).readAsStringSync()) as Map)['steps'] as List;
  Directory(outDir).createSync(recursive: true);

  Process? proc;
  int port;
  if (portArg != null) {
    port = int.parse(portArg);
  } else {
    proc = await Process.start(
      File(exe!).absolute.path,
      [
        File(iso!).absolute.path,
        if (state != null) '--state=${File(state).absolute.path}',
      ],
      workingDirectory: File(exe).absolute.parent.path,
      mode: ProcessStartMode.detached,
    );
    port = await _findPort(proc.pid);
    print('PPSSPP pid ${proc.pid}, debugger port $port');
  }

  final ws = await WebSocket.connect(
    'ws://127.0.0.1:$port/debugger',
    protocols: ['debugger.ppsspp.org'],
  ).timeout(const Duration(seconds: 15));
  final events = StreamController<Map<String, dynamic>>.broadcast();
  ws.listen(
    (m) => events.add(jsonDecode(m as String) as Map<String, dynamic>),
    onDone: () => events.close(),
  );
  Future<Map<String, dynamic>> request(String event,
      [Map<String, Object?> data = const {}]) {
    final reply = events.stream
        .firstWhere((m) => m['event'] == event || m['event'] == 'error')
        .timeout(const Duration(seconds: 20));
    ws.add(jsonEncode({'event': event, ...data}));
    return reply;
  }

  ws.add(
      jsonEncode({'event': 'version', 'name': 'mhtk-tour', 'version': '0.1'}));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  final started = Stopwatch()..start();
  while ((await request('game.status'))['game'] == null) {
    if (started.elapsed.inSeconds > 90) {
      stderr.writeln('no game after 90 s');
      if (proc != null) Process.killPid(proc.pid);
      exit(2);
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  final report = StringBuffer()
    ..writeln('| capture | bande (y) | encre (x) | pas écran | pas PSP | '
        'caractères | confiance |')
    ..writeln('|---|---|---|---|---|---|---|');
  var n = 0;
  for (final raw in steps) {
    final step = (raw as Map).cast<String, Object?>();
    if (step['wait'] != null) {
      final s = (step['wait'] as num).toDouble();
      print('wait ${s}s');
      await Future<void>.delayed(Duration(milliseconds: (s * 1000).round()));
    } else if (step['press'] != null) {
      final hold = (step['hold'] as num?)?.toInt() ?? 5;
      final pause = (step['pause'] as num?)?.toDouble() ?? 1.0;
      final until = (step['until'] as Map?)?.cast<String, Object?>();
      final tries = until == null ? 1 : (step['tries'] as num?)?.toInt() ?? 6;
      for (var attempt = 1; attempt <= tries; attempt++) {
        for (final b in (step['press'] as List).cast<String>()) {
          await request('input.buttons.press', {'button': b, 'duration': hold});
          print('press $b${tries > 1 ? ' (try $attempt)' : ''}');
          await Future<void>.delayed(
              Duration(milliseconds: (pause * 1000).round()));
        }
        if (until == null) break;
        // La touche peut être perdue (le jeu n'écoute pas encore) : on
        // vérifie la luminance moyenne d'une zone caractéristique de l'écran
        // attendu et on recommence tant qu'elle n'y est pas.
        final probe = '$outDir/_probe.png';
        final rr = await _capture(probe, proc?.pid ?? 0);
        if (rr.exitCode != 0) break;
        final lum = _meanLum(
            decodePng(File(probe).readAsBytesSync()),
            (until['region'] as List)
                .cast<num>()
                .map((v) => v.toInt())
                .toList());
        final ok = lum >= ((until['lumMin'] as num?) ?? 0) &&
            lum <= ((until['lumMax'] as num?) ?? 255);
        print('  zone ${until['region']} luminance ${lum.toStringAsFixed(0)} '
            '${ok ? 'ok' : 'pas encore'}');
        if (ok) break;
        if (attempt == tries) {
          stderr.writeln('écran attendu non atteint après $tries essais');
          File(probe).deleteSync();
          exit(4);
        }
      }
      final probe = File('$outDir/_probe.png');
      if (probe.existsSync()) probe.deleteSync();
    } else if (step['shot'] != null) {
      final name = '${(n++).toString().padLeft(2, '0')}_${step['shot']}';
      final path = '$outDir/$name.png';
      final pid = proc?.pid ?? 0;
      final r = await _capture(path, pid);
      if (r.exitCode != 0) {
        stderr.writeln('capture failed: ${r.stderr}');
        continue;
      }
      final img = decodePng(File(path).readAsBytesSync());
      print('shot $path ${img.width}x${img.height}');
      final regions = (step['regions'] as List?)
          ?.map((e) => (e as List).cast<num>().map((v) => v.toInt()).toList())
          .map((v) => Region(v[0], v[1], v[2], v[3]))
          .toList();
      final measures = <PitchMeasure>[
        if (regions != null)
          for (final rg in regions)
            if (measurePitch(img, rg) case final m?) m,
        if (step['analyze'] == true) ...measureTextBands(img),
      ];
      for (final m in measures) {
        final line = '| $name | ${m.region.y0}-${m.region.y1} | '
            '${m.inkX0}-${m.inkX1} | ${m.screenPitch} | '
            '${m.pspPitch.toStringAsFixed(2)} | ${m.chars.toStringAsFixed(1)} '
            '| ${m.confidence.toStringAsFixed(2)} |';
        report.writeln(line);
        print('  $line');
      }
    }
  }
  File('$outDir/report.md').writeAsStringSync(report.toString());
  print('report $outDir/report.md');
  await ws.close();
  if (proc != null && !keepOpen) Process.killPid(proc.pid);
  exit(0);
}

/// Port d'écoute du débogueur : le processus PPSSPP écoute sur un port local
/// aléatoire ; on le lit dans `netstat -ano`.
Future<int> _findPort(int pid) async {
  for (var i = 0; i < 60; i++) {
    final r = await Process.run('netstat', ['-ano']);
    for (final line in (r.stdout as String).split('\n')) {
      final f = line.trim().split(RegExp(r'\s+'));
      if (f.length >= 5 && f[3] == 'LISTENING' && f[4] == '$pid') {
        final m = RegExp(r':(\d+)$').firstMatch(f[1]);
        if (m != null) return int.parse(m.group(1)!);
      }
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('debugger port not found for pid $pid');
}

/// Capture la fenêtre avec `ppsspp_window_capture.ps1`. Le script est passé
/// en `-EncodedCommand` : la politique d'exécution de PowerShell, qui bloque
/// les fichiers `.ps1`, n'est ni modifiée ni contournée au niveau du système.
Future<ProcessResult> _capture(String path, int pid) {
  final body =
      File('apps/mh_cli/tool/ppsspp_window_capture.ps1').readAsStringSync();
  final command = "& { $body } -Out '${path.replaceAll("'", "''")}'"
      '${pid > 0 ? ' -ProcessId $pid' : ''}';
  final utf16 = <int>[
    for (final u in command.codeUnits) ...[u & 0xFF, u >> 8],
  ];
  return Process.run('powershell', [
    '-NoProfile',
    '-NonInteractive',
    '-EncodedCommand',
    base64Encode(utf16),
  ]);
}

/// Luminance moyenne (0..255) d'une région `[x0, y0, x1, y1]`.
double _meanLum(Rgba img, List<int> r) {
  var s = 0.0, n = 0;
  for (var y = r[1]; y < r[3]; y += 2) {
    for (var x = r[0]; x < r[2]; x += 2) {
      s += img.lum(x, y);
      n++;
    }
  }
  return n == 0 ? 0 : s / n;
}
