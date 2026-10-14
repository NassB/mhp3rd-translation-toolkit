import 'dart:io';

import 'package:mh_cli/mh_cli.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'index') {
    exitCode = await runIndex(args.sublist(1), stdout, stderr);
    return;
  }
  stderr.writeln('usage: mhtk index <DATA.BIN> | --iso <game.iso>');
  exitCode = 64;
}
