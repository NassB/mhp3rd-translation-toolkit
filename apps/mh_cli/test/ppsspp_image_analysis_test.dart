import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../tool/ppsspp/image_analysis.dart';

/// Image synthétique : fond [bg], « texte » de cellules de [glyph] px de large
/// toutes les [pitch] px à partir de [x0], sur les lignes [y0, y1).
Rgba synthetic({
  int width = 960,
  int height = 200,
  int bg = 20,
  int fg = 240,
  required List<(int y0, int y1, int x0, int cells, int pitch, int glyph)>
      lines,
}) {
  final px = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    px[i * 4] = bg;
    px[i * 4 + 1] = bg;
    px[i * 4 + 2] = bg;
    px[i * 4 + 3] = 255;
  }
  for (final (y0, y1, x0, cells, pitch, glyph) in lines) {
    for (var c = 0; c < cells; c++) {
      for (var y = y0; y < y1; y++) {
        for (var x = 0; x < glyph; x++) {
          final o = (y * width + x0 + c * pitch + x) * 4;
          px[o] = fg;
          px[o + 1] = fg;
          px[o + 2] = fg;
        }
      }
    }
  }
  return Rgba(width, height, px);
}

int _crc(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// PNG RGBA 8 bits ; [filter] : type de filtre appliqué à chaque ligne.
Uint8List encodePng(Rgba img, {int filter = 0}) {
  final raw = BytesBuilder();
  final stride = img.width * 4;
  final prev = Uint8List(stride);
  for (var y = 0; y < img.height; y++) {
    final row = img.pixels.sublist(y * stride, (y + 1) * stride);
    raw.addByte(filter);
    for (var i = 0; i < stride; i++) {
      final a = i >= 4 ? row[i - 4] : 0;
      final b = prev[i];
      final c = i >= 4 ? prev[i - 4] : 0;
      final pred = switch (filter) {
        0 => 0,
        1 => a,
        2 => b,
        3 => (a + b) >> 1,
        _ => _paeth(a, b, c),
      };
      raw.addByte((row[i] - pred) & 0xFF);
    }
    prev.setAll(0, row);
  }
  final out = BytesBuilder()
    ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final body = [...type.codeUnits, ...data];
    out.add(body);
    final crc = ByteData(4)..setUint32(0, _crc(body));
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, img.width)
    ..setUint32(4, img.height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder().convert(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

void main() {
  group('decodePng', () {
    test('round-trips every PNG filter type', () {
      final img = synthetic(
        width: 64,
        height: 20,
        lines: [(2, 9, 3, 5, 10, 6)],
      );
      for (final f in [0, 1, 2, 3, 4]) {
        final back = decodePng(encodePng(img, filter: f));
        expect(back.width, 64, reason: 'filter $f');
        expect(back.height, 20);
        expect(back.pixels, img.pixels, reason: 'filter $f');
      }
    });

    test('rejects what it does not support', () {
      expect(() => decodePng(Uint8List(4)), throwsFormatException);
      final png = encodePng(synthetic(width: 8, height: 4, lines: const []));
      png[24] = 16; // profondeur 16 bits
      expect(() => decodePng(png), throwsFormatException);
    });
  });

  group('measurePitch', () {
    test('finds a 14 px pitch (7 px on the PSP at scale 2)', () {
      final img = synthetic(lines: [(30, 48, 100, 30, 14, 9)]);
      final m = measurePitch(img, const Region(0, 20, 960, 60))!;
      expect(m.screenPitch, 14);
      expect(m.pspPitch, 7.0);
      expect(m.confidence, greaterThan(0.5));
      expect(m.inkX0, 100);
      expect(m.chars, closeTo(30, 1));
    });

    test('takes the smallest period, not its multiples', () {
      // Une cellule sur deux est vide : la période réelle est 12, mais la
      // structure se répète aussi tous les 24.
      final img = synthetic(lines: [(30, 48, 50, 40, 12, 7)]);
      final m = measurePitch(img, const Region(0, 20, 960, 60))!;
      expect(m.screenPitch, 12);
      expect(m.pspPitch, 6.0);
    });

    test('measures another pitch and works at another scale', () {
      final img = synthetic(
        width: 480,
        height: 100,
        lines: [(10, 22, 20, 30, 9, 6)],
      );
      final m = measurePitch(img, const Region(0, 5, 480, 30))!;
      expect(m.screenPitch, 9);
      expect(m.pspPitch, 9.0); // échelle 1
    });

    test('white text on a dark background and the reverse give the same pitch',
        () {
      final dark = synthetic(lines: [(30, 48, 100, 30, 14, 9)]);
      final light =
          synthetic(bg: 230, fg: 30, lines: [(30, 48, 100, 30, 14, 9)]);
      expect(
        measurePitch(dark, const Region(0, 20, 960, 60))!.screenPitch,
        measurePitch(light, const Region(0, 20, 960, 60))!.screenPitch,
      );
    });

    test('returns null without text, with too little ink or no rhythm', () {
      expect(
        measurePitch(synthetic(lines: const []), const Region(0, 0, 960, 60)),
        isNull,
      );
      final one = synthetic(lines: [(30, 48, 100, 1, 14, 9)]);
      expect(measurePitch(one, const Region(0, 20, 960, 60)), isNull);
      final solid = synthetic(lines: [(30, 48, 100, 1, 14, 600)]);
      expect(measurePitch(solid, const Region(0, 20, 960, 60)), isNull);
    });
  });

  group('measureTextBands', () {
    test('finds each line of a multi-line text', () {
      final img = synthetic(
        height: 300,
        lines: [
          (30, 48, 100, 30, 14, 9),
          (80, 98, 120, 24, 14, 9),
          (150, 168, 90, 20, 12, 8),
        ],
      );
      final bands = measureTextBands(img);
      expect([for (final b in bands) b.screenPitch], [14, 14, 12]);
      expect([for (final b in bands) b.region.y0], [30, 80, 150]);
      expect([for (final b in bands) b.pspPitch], [7.0, 7.0, 6.0]);
    });
  });

  test('a real file round-trips through disk', () {
    final dir = Directory.systemTemp.createTempSync('mh_png');
    addTearDown(() => dir.deleteSync(recursive: true));
    final img = synthetic(width: 32, height: 8, lines: [(1, 6, 2, 3, 8, 5)]);
    final f = File('${dir.path}/a.png')..writeAsBytesSync(encodePng(img));
    expect(decodePng(f.readAsBytesSync()).pixels, img.pixels);
  });
}
