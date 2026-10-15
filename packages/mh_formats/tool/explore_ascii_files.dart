// ignore_for_file: type=lint
// Exploration: distribution des string_table_a ASCII purs (hors 17, 2813-2819).
// Usage: dart run packages/mh_formats/tool/explore_ascii_files.dart local/MHP3.iso
import 'dart:io';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_databin/mh_databin.dart';
import 'package:mh_formats/mh_formats.dart';
import 'package:mh_iso/mh_iso.dart';

String hx(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');

String ranges(List<int> ids) {
  if (ids.isEmpty) return '-';
  ids = [...ids]..sort();
  final parts = <String>[];
  var s = ids.first, p = ids.first;
  for (final i in ids.skip(1)) {
    if (i == p + 1) {
      p = i;
      continue;
    }
    parts.add(s == p ? '$s' : '$s-$p');
    s = p = i;
  }
  parts.add(s == p ? '$s' : '$s-$p');
  return parts.join(',');
}

Future<void> main(List<String> a) async {
  final reg = GameVersionRegistry.fromFile('config/game_versions.yaml');
  final img = await FileIsoImage.open(a[0], reg);
  final raf = File(a[0]).openSync();
  final base = img.dataBin.offset;
  Uint8List readAt(int o, int l) {
    raf.setPositionSync(base + o);
    final out = Uint8List(l);
    var g = 0;
    while (g < l) {
      final n = raf.readIntoSync(out, g);
      if (n == 0) throw StateError('eof');
      g += n;
    }
    return out;
  }

  const c = DataCipher();
  final idx = DataBinIndex.build(readAt, img.dataBin.size);
  final out = StringBuffer();
  final rows = <Map<String, Object>>[];
  final lens = <int>[];
  final slotKinds = <String, int>{};
  final examples = <String>[];
  var allZeroFiles = 0;

  for (final e in idx.entries) {
    if (e.slotBytes == 0) continue;
    if (e.id == 17 || (e.id >= 2813 && e.id <= 2819)) continue;
    final raw = readAt(e.offset, e.slotBytes);
    final plain = e.encrypted ? c.decrypt(raw, e.lba) : raw;
    final StringTableFile f;
    try {
      f = decodeStringTableA(plain, fileId: e.id);
    } on FormatError {
      continue;
    }
    var slots = 0, nonEmpty = 0, nulls = 0, nonNull = 0, aliases = 0;
    var ascii = true;
    final fileLens = <int>[];
    for (final t in f.tables) {
      if (t == null) {
        nulls++;
        continue;
      }
      nonNull++;
      for (final s in t.slots) {
        slots++;
        if (s.aliasOf != null) aliases++;
        if (s.raw.isNotEmpty) {
          nonEmpty++;
          fileLens.add(s.raw.length);
          if (s.raw.any((x) => x >= 0x80)) ascii = false;
        }
      }
    }
    if (!ascii) continue;
    final nz = plain.where((x) => x != 0).length;
    if (nz == 0) allZeroFiles++;
    rows.add({
      'id': e.id,
      'size': plain.length,
      'count': f.tables.length,
      'unk': f.unknownHeader,
      'nulls': nulls,
      'nonNull': nonNull,
      'slots': slots,
      'nonEmpty': nonEmpty,
      'aliases': aliases,
      'end': f.endData.length,
      'nz': nz,
      'zero': nz == 0 ? 1 : 0,
    });
    lens.addAll(fileLens);
    if (nonEmpty > 0 && examples.length < 400) {
      for (final t in f.tables) {
        if (t == null) continue;
        for (final s in t.slots) {
          if (s.raw.isEmpty) continue;
          final txt = String.fromCharCodes(s.raw);
          final kind = RegExp(r'^[0-9]+$').hasMatch(txt)
              ? 'digits'
              : RegExp(r'^[A-Za-z0-9_.\-]+$').hasMatch(txt)
                  ? 'ident/filename'
                  : txt.contains('/')
                      ? 'path'
                      : RegExp(r'^[\x20-\x7e]+$').hasMatch(txt)
                          ? 'printable-other'
                          : 'has-control';
          slotKinds[kind] = (slotKinds[kind] ?? 0) + 1;
          if (examples.length < 400)
            examples.add(
                '${e.id}:$kind:${s.raw.length}:${hx(s.raw.take(20).toList())}');
        }
      }
    }
  }

  out.writeln('ascii files=${rows.length} allZeroPlain=$allZeroFiles');
  String cl(Map<String, Object> r) {
    final s = r['slots']! as int, n = r['nonEmpty']! as int;
    if (s == 0) return 'A: 0 slot';
    if (n == 0) return 'B: slots tous vides';
    if (s <= 3) return 'C: 1-3 slots';
    return 'D: >3 slots';
  }

  final byCls = <String, List<Map<String, Object>>>{};
  for (final r in rows) {
    (byCls[cl(r)] ??= []).add(r);
  }
  for (final k in byCls.keys.toList()..sort()) {
    final l = byCls[k]!;
    final sizes = l.map((r) => r['size']! as int).toList()..sort();
    final cnts = <int, int>{};
    for (final r in l) {
      cnts[r['count']! as int] = (cnts[r['count']! as int] ?? 0) + 1;
    }
    out.writeln(
        '$k: n=${l.length} sizes min/med/max=${sizes.first}/${sizes[sizes.length ~/ 2]}/${sizes.last} '
        'tablesCount hist=$cnts');
    out.writeln('   ids: ${ranges(l.map((r) => r['id']! as int).toList())}');
    out.writeln(
        '   unk values: ${(l.map((r) => r['unk']).toSet().take(8)).toList()} '
        'sumNulls=${l.fold<int>(0, (s, r) => s + (r['nulls']! as int))} '
        'sumNonNull=${l.fold<int>(0, (s, r) => s + (r['nonNull']! as int))} '
        'sumSlots=${l.fold<int>(0, (s, r) => s + (r['slots']! as int))} '
        'sumNonEmpty=${l.fold<int>(0, (s, r) => s + (r['nonEmpty']! as int))} '
        'endData min/max=${l.map((r) => r['end']! as int).reduce((a, b) => a < b ? a : b)}/${l.map((r) => r['end']! as int).reduce((a, b) => a > b ? a : b)} '
        'nonzeroBytes min/max=${l.map((r) => r['nz']! as int).reduce((a, b) => a < b ? a : b)}/${l.map((r) => r['nz']! as int).reduce((a, b) => a > b ? a : b)}');
  }
  lens.sort();
  if (lens.isNotEmpty) {
    out.writeln(
        'slot len min/med/max=${lens.first}/${lens[lens.length ~/ 2]}/${lens.last} n=${lens.length}');
  }
  out.writeln('slot kinds: $slotKinds');
  out.writeln(
      '\n-- per-file rows (id size count unk nulls nonNull slots nonEmpty aliases end nz)');
  for (final r in rows) {
    out.writeln(r.values.join(' '));
  }
  out.writeln('\n-- examples (id:kind:len:hex<=20B)');
  examples.forEach(out.writeln);
  Directory('local/explore').createSync(recursive: true);
  File('local/explore/ascii_files.txt').writeAsStringSync(out.toString());
  print(out
      .toString()
      .split('\n')
      .takeWhile((l) => !l.startsWith('-- per-file'))
      .join('\n'));
}
