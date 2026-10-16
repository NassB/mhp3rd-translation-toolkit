// Analyse d'une capture de PPSSPP (T44, docs/QA_PPSSPP.md §10) : décodage PNG
// minimal (sans dépendance) et mesure du pas des caractères par
// autocorrélation du profil d'encre des colonnes.
//
// La police latine du jeu est à chasse fixe (docs/CALIBRATION.md §5) : sur une
// ligne de texte, le profil des colonnes « encrées » se répète tous les
// `pas` pixels. Le pas en pixels de la PSP est ce pas d'écran divisé par
// l'échelle (largeur de l'image / 480).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Image RGBA 8 bits.
final class Rgba {
  Rgba(this.width, this.height, this.pixels);

  final int width;
  final int height;

  /// 4 octets par pixel (R, G, B, A), ligne par ligne.
  final Uint8List pixels;

  /// Luminance (0..255) du pixel (x, y).
  double lum(int x, int y) {
    final i = (y * width + x) * 4;
    return 0.3 * pixels[i] + 0.59 * pixels[i + 1] + 0.11 * pixels[i + 2];
  }

  /// Échelle d'affichage : pixels d'écran par pixel de la PSP (480 de large).
  double get scale => width / 480;
}

/// Décode un PNG 8 bits RGB ou RGBA, sans entrelacement. Lève
/// [FormatException] pour tout autre PNG.
Rgba decodePng(Uint8List bytes) {
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    if (bytes.length < 8 || bytes[i] != sig[i]) {
      throw const FormatException('not a PNG');
    }
  }
  final bd = ByteData.sublistView(bytes);
  var pos = 8;
  var width = 0, height = 0, depth = 0, colorType = 0, interlace = 0;
  final idat = BytesBuilder();
  while (pos + 8 <= bytes.length) {
    final len = bd.getUint32(pos);
    final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
    final data = pos + 8;
    if (type == 'IHDR') {
      width = bd.getUint32(data);
      height = bd.getUint32(data + 4);
      depth = bytes[data + 8];
      colorType = bytes[data + 9];
      interlace = bytes[data + 12];
    } else if (type == 'IDAT') {
      idat.add(bytes.sublist(data, data + len));
    } else if (type == 'IEND') {
      break;
    }
    pos = data + len + 4; // données + CRC
  }
  if (depth != 8 || (colorType != 2 && colorType != 6) || interlace != 0) {
    throw FormatException(
      'unsupported PNG (depth $depth, color type $colorType, '
      'interlace $interlace)',
    );
  }
  final channels = colorType == 6 ? 4 : 3;
  final raw = Uint8List.fromList(ZLibDecoder().convert(idat.toBytes()));
  final stride = width * channels;
  if (raw.length < (stride + 1) * height) {
    throw const FormatException('truncated PNG data');
  }
  final out = Uint8List(width * height * 4);
  final prev = Uint8List(stride);
  final cur = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final base = y * (stride + 1);
    final filter = raw[base];
    for (var i = 0; i < stride; i++) {
      final x = raw[base + 1 + i];
      final a = i >= channels ? cur[i - channels] : 0;
      final b = prev[i];
      final c = i >= channels ? prev[i - channels] : 0;
      cur[i] = switch (filter) {
        0 => x,
        1 => (x + a) & 0xFF,
        2 => (x + b) & 0xFF,
        3 => (x + ((a + b) >> 1)) & 0xFF,
        4 => (x + _paeth(a, b, c)) & 0xFF,
        _ => throw FormatException('bad PNG filter $filter'),
      };
    }
    for (var x = 0; x < width; x++) {
      final o = (y * width + x) * 4;
      out[o] = cur[x * channels];
      out[o + 1] = cur[x * channels + 1];
      out[o + 2] = cur[x * channels + 2];
      out[o + 3] = channels == 4 ? cur[x * channels + 3] : 255;
    }
    prev.setAll(0, cur);
  }
  return Rgba(width, height, out);
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/// Une région rectangulaire en pixels d'écran (bornes incluses au début,
/// exclues à la fin).
final class Region {
  const Region(this.x0, this.y0, this.x1, this.y1);

  final int x0, y0, x1, y1;

  @override
  String toString() => '$x0,$y0,$x1,$y1';
}

/// Résultat de la mesure d'une ligne de texte.
final class PitchMeasure {
  const PitchMeasure({
    required this.region,
    required this.inkX0,
    required this.inkX1,
    required this.screenPitch,
    required this.pspPitch,
    required this.confidence,
  });

  /// Bande analysée.
  final Region region;

  /// Étendue horizontale de l'encre (pixels d'écran).
  final int inkX0, inkX1;

  /// Pas en pixels d'écran (entier le plus proche du pic d'autocorrélation).
  final int screenPitch;

  /// Pas en pixels de la PSP (`screenPitch / échelle`).
  final double pspPitch;

  /// 0..1 : force du pic (autocorrélation normalisée).
  final double confidence;

  /// Nombre de caractères que couvre l'encre, d'après le pas.
  double get chars => (inkX1 - inkX0 + 1) / screenPitch;
}

/// Profil binaire des colonnes de [region] : 1 si la colonne contient de
/// l'encre (pixel dont la luminance diffère de plus de [threshold] de la
/// médiane de la bande).
List<int> inkColumns(Rgba img, Region r, {double threshold = 70}) {
  final w = r.x1 - r.x0, h = r.y1 - r.y0;
  final lums = <double>[
    for (var y = r.y0; y < r.y1; y++)
      for (var x = r.x0; x < r.x1; x++) img.lum(x, y),
  ]..sort();
  final median = lums[lums.length ~/ 2];
  final cols = List<int>.filled(w, 0);
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      if ((img.lum(r.x0 + x, r.y0 + y) - median).abs() > threshold) {
        cols[x] = 1;
        break;
      }
    }
  }
  return cols;
}

/// Mesure le pas des caractères d'une bande de texte. `null` si la bande
/// contient trop peu d'encre ou aucune périodicité nette.
///
/// [minPitch] et [maxPitch] bornent le pas d'écran cherché (par défaut 8 à
/// 40 px). Parmi les décalages dont la corrélation atteint 90 % du maximum,
/// on retient le **plus petit** (les multiples du pas corrèlent aussi).
PitchMeasure? measurePitch(
  Rgba img,
  Region r, {
  int minPitch = 8,
  int maxPitch = 40,
  double minConfidence = 0.25,
}) {
  final cols = inkColumns(img, r);
  final a = cols.indexOf(1);
  final b = cols.lastIndexOf(1);
  if (a < 0 || b - a < minPitch * 4) return null;
  final seg = cols.sublist(a, b + 1);
  final mean = seg.reduce((x, y) => x + y) / seg.length;
  var variance = 0.0;
  for (final v in seg) {
    variance += (v - mean) * (v - mean);
  }
  variance /= seg.length;
  if (variance < 1e-9) return null;

  final corr = <int, double>{};
  for (var lag = minPitch; lag <= math.min(maxPitch, seg.length ~/ 2); lag++) {
    var s = 0.0;
    var n = 0;
    for (var i = 0; i + lag < seg.length; i++) {
      s += (seg[i] - mean) * (seg[i + lag] - mean);
      n++;
    }
    corr[lag] = s / n / variance;
  }
  if (corr.isEmpty) return null;
  final best = corr.values.reduce(math.max);
  if (best < minConfidence) return null;
  final lag = (corr.entries.toList()..sort((x, y) => x.key - y.key))
      .firstWhere((e) => e.value >= 0.9 * best)
      .key;
  return PitchMeasure(
    region: r,
    inkX0: r.x0 + a,
    inkX1: r.x0 + b,
    screenPitch: lag,
    pspPitch: lag / img.scale,
    confidence: corr[lag]!,
  );
}

/// Détecte les bandes de texte de [area] (toute l'image par défaut) : lignes
/// de pixels contiguës dont la luminance varie nettement, de hauteur
/// plausible pour une ligne de texte (de [minHeight] à [maxHeight] pixels
/// d'écran), puis mesure le pas de chacune ; seuls les pas de [minPspPitch] à
/// [maxPspPitch] pixels de la PSP et d'une confiance d'au moins [minConfidence]
/// sont retenus (le reste est du décor).
List<PitchMeasure> measureTextBands(
  Rgba img, {
  Region? area,
  int minHeight = 12,
  int maxHeight = 60,
  double minPspPitch = 5,
  double maxPspPitch = 12,
  double minConfidence = 0.5,
}) {
  final r = area ?? Region(0, 0, img.width, img.height);
  // Une ligne est « active » si elle contient assez de pixels d'encre.
  final active = <bool>[];
  for (var y = r.y0; y < r.y1; y++) {
    var changes = 0;
    var prev = img.lum(r.x0, y) > 128;
    for (var x = r.x0 + 1; x < r.x1; x++) {
      final cur = img.lum(x, y) > 128;
      if (cur != prev) changes++;
      prev = cur;
    }
    active.add(changes >= 12);
  }
  final out = <PitchMeasure>[];
  var y = 0;
  while (y < active.length) {
    if (!active[y]) {
      y++;
      continue;
    }
    var end = y;
    while (end < active.length && active[end]) {
      end++;
    }
    final h = end - y;
    if (h >= minHeight && h <= maxHeight) {
      final m = measurePitch(
        img,
        Region(r.x0, r.y0 + y, r.x1, r.y0 + end),
        minPitch: (minPspPitch * img.scale).floor(),
        maxPitch: (maxPspPitch * img.scale).ceil(),
        minConfidence: minConfidence,
      );
      if (m != null) out.add(m);
    }
    y = end + 1;
  }
  return out;
}
