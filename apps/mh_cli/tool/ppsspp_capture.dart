// ignore_for_file: type=lint
// T44 — étude de faisabilité : piloter PPSSPP par son débogueur WebSocket
// (docs/QA_PPSSPP.md §10). Se connecte à une instance de PPSSPP lancée avec
// « RemoteDebuggerOnStartup = True », met l'émulation en pause, enregistre
// une capture PNG de l'écran (`gpu.buffer.screenshot`) et relance.
//
//   dart run apps/mh_cli/tool/ppsspp_capture.dart [--port 56666] [--out dossier]
//       [--wait-game 120] [--press cross,start ...] [--shots N --every S]
//
// Les captures sont des images du jeu : elles restent dans `out/` (ignoré par
// git) et ne doivent pas être publiées.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  var port = 56666;
  var outDir = 'out/ppsspp_shots';
  var waitGame = 120;
  var shots = 1;
  var every = 2;
  final presses = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port':
        port = int.parse(args[++i]);
      case '--out':
        outDir = args[++i];
      case '--wait-game':
        waitGame = int.parse(args[++i]);
      case '--shots':
        shots = int.parse(args[++i]);
      case '--every':
        every = int.parse(args[++i]);
      case '--press':
        presses.addAll(args[++i].split(','));
    }
  }
  Directory(outDir).createSync(recursive: true);

  // Connexion avec le sous-protocole du débogueur de PPSSPP.
  final ws = await WebSocket.connect(
    'ws://127.0.0.1:$port/debugger',
    protocols: ['debugger.ppsspp.org'],
  ).timeout(const Duration(seconds: 10));
  print('connected (protocol ${ws.protocol})');

  final events = StreamController<Map<String, dynamic>>.broadcast();
  ws.listen(
    (m) => events.add(jsonDecode(m as String) as Map<String, dynamic>),
    onDone: () => events.close(),
  );

  Future<Map<String, dynamic>> request(
    String event, [
    Map<String, Object?> data = const {},
    Duration timeout = const Duration(seconds: 15),
  ]) {
    final reply = events.stream
        .firstWhere((m) => m['event'] == event || m['event'] == 'error')
        .timeout(timeout);
    ws.add(jsonEncode({'event': event, ...data}));
    return reply;
  }

  ws.add(jsonEncode(
      {'event': 'version', 'name': 'mhtk-capture', 'version': '0.1'}));
  await Future<void>.delayed(const Duration(milliseconds: 300));

  // Attendre que le jeu soit démarré.
  final started = Stopwatch()..start();
  while (true) {
    final r = await request('game.status');
    final game = r['game'];
    final stepping = r['stepping'];
    print('game.status: ${jsonEncode({
          'game': game == null ? null : 'loaded',
          'stepping': stepping
        })}');
    if (game != null) break;
    if (started.elapsed.inSeconds > waitGame) {
      print('no game after ${waitGame}s');
      exit(2);
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }

  for (final b in presses) {
    final r =
        await request('input.buttons.press', {'button': b, 'duration': 5});
    print('pressed $b -> ${r['event']}');
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  for (var n = 0; n < shots; n++) {
    if (n > 0) await Future<void>.delayed(Duration(seconds: every));
    final sw = Stopwatch()..start();
    await request('cpu.stepping');
    // Laisser le GPU s'arrêter avant la capture.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final shot = await request('gpu.buffer.screenshot', {'type': 'uri'});
    await request('cpu.resume');
    if (shot['event'] == 'error') {
      print('error: ${shot['message']}');
      exit(3);
    }
    final uri = shot['uri'] as String;
    final bytes = base64Decode(uri.substring(uri.indexOf(',') + 1));
    final path = '$outDir/shot_${n.toString().padLeft(3, '0')}.png';
    File(path).writeAsBytesSync(bytes);
    print('saved $path ${shot['width']}x${shot['height']} '
        '${bytes.length} bytes in ${sw.elapsedMilliseconds} ms');
  }
  await ws.close();
}
