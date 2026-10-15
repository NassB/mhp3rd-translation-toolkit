import 'dart:io';

import 'package:mh_cli/mh_cli.dart';

const String _usage = '''
usage: mhtk <command> [options]

commands:
  index    summarize DATA.BIN (file or --iso)
  init     create a project from an ISO
  extract  detect and import the text tables into the project database
  status   show the project database content''';

Future<void> main(List<String> args) async {
  final rest = args.isEmpty ? <String>[] : args.sublist(1);
  switch (args.isEmpty ? '' : args.first) {
    case 'index':
      exitCode = await runIndex(rest, stdout, stderr);
    case 'init':
      exitCode = await runInit(rest, stdout, stderr);
    case 'extract':
      exitCode = await runExtract(rest, stdout, stderr);
    case 'status':
      exitCode = await runStatus(rest, stdout, stderr);
    default:
      stderr.writeln(_usage);
      exitCode = 64;
  }
}
