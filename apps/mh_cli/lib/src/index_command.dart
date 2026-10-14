import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_iso/mh_iso.dart';

const String _usage = 'usage: mhtk index <DATA.BIN> | --iso <game.iso> '
    '[--config config/game_versions.yaml]';

/// `mhtk index` : résumé de la TOC de `DATA.BIN` (nombre de fichiers,
/// plus gros slot, somme des slots). Retourne le code de sortie.
Future<int> runIndex(List<String> args, StringSink out, StringSink err) async {
  String? dataBinPath;
  String? isoPath;
  var config = 'config/game_versions.yaml';
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--iso' when i + 1 < args.length:
        isoPath = args[++i];
      case '--config' when i + 1 < args.length:
        config = args[++i];
      case final a when !a.startsWith('--') && dataBinPath == null:
        dataBinPath = a;
      default:
        err.writeln(_usage);
        return 64;
    }
  }
  if ((dataBinPath == null) == (isoPath == null)) {
    err.writeln(_usage);
    return 64;
  }

  FileIsoImage? img;
  RandomAccessFile? raf;
  try {
    final int base;
    final int size;
    if (isoPath != null) {
      img = await FileIsoImage.open(
        isoPath,
        GameVersionRegistry.fromFile(config),
      );
      raf = File(isoPath).openSync();
      base = img.dataBin.offset;
      size = img.dataBin.size;
    } else {
      raf = File(dataBinPath!).openSync();
      base = 0;
      size = raf.lengthSync();
    }
    final file = raf;
    Uint8List readAt(int offset, int length) {
      file.setPositionSync(base + offset);
      final buf = Uint8List(length);
      var got = 0;
      while (got < length) {
        final n = file.readIntoSync(buf, got);
        if (n == 0) {
          throw FormatError('short read of DATA.BIN', offset: offset + got);
        }
        got += n;
      }
      return buf;
    }

    final index = DataBinIndex.build(readAt, size);
    final biggest = index.entries.reduce(
      (a, b) => b.slotBytes > a.slotBytes ? b : a,
    );
    final total = index.entries.fold<int>(0, (s, e) => s + e.slotBytes);
    out
      ..writeln('files:        ${index.entries.length}')
      ..writeln(
        'largest slot: ${biggest.slotBytes} bytes '
        '(id ${biggest.id}, mod id ${biggest.modId})',
      )
      ..writeln('total slots:  $total bytes');
    return 0;
  } on MhError catch (e) {
    err.writeln('error: $e');
    return 1;
  } on FileSystemException catch (e) {
    err.writeln('error: ${e.message}: ${e.path}');
    return 1;
  } finally {
    raf?.closeSync();
    img?.close();
  }
}
