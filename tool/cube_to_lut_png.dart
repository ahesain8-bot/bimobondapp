// Converts a .cube 3D LUT into a 512x512 PNG "lookup" LUT (GPUImage layout:
// 8x8 tiles of 64x64 = a 64^3 cube) that the app's OpenGL/CPU samplers read.
//
// This runs OFFLINE (dev time) only — the app never parses .cube at runtime,
// it just loads the resulting PNG as a GPU texture (fast).
//
// Usage:
//   dart run tool/cube_to_lut_png.dart "assets/luts/cube/My LUT.cube" assets/luts/cityfilm.png
//
// The output layout MUST match tool/generate_luts.dart / LutStore.kt / the GLSL
// applyLut() so live preview and the baked photo match.
import 'dart:io';

import 'package:image/image.dart' as img;

const int _tiles = 8;
const int _size = 64; // output levels per channel
const int _dim = _tiles * _size; // 512

class _Cube {
  _Cube(this.n, this.data);
  final int n;
  final List<double> data; // n*n*n*3, red fastest then green then blue

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// Trilinear sample at (r,g,b) in 0..1 -> [r,g,b] in 0..1.
  List<double> sample(double r, double g, double b) {
    final fr = _clamp01(r) * (n - 1);
    final fg = _clamp01(g) * (n - 1);
    final fb = _clamp01(b) * (n - 1);
    final r0 = fr.floor();
    final g0 = fg.floor();
    final b0 = fb.floor();
    final r1 = (r0 + 1).clamp(0, n - 1);
    final g1 = (g0 + 1).clamp(0, n - 1);
    final b1 = (b0 + 1).clamp(0, n - 1);
    final dr = fr - r0;
    final dg = fg - g0;
    final db = fb - b0;

    List<double> at(int ri, int gi, int bi) {
      final idx = (ri + gi * n + bi * n * n) * 3;
      return [data[idx], data[idx + 1], data[idx + 2]];
    }

    List<double> lerp(List<double> a, List<double> c, double t) =>
        [a[0] + (c[0] - a[0]) * t, a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t];

    final c000 = at(r0, g0, b0);
    final c100 = at(r1, g0, b0);
    final c010 = at(r0, g1, b0);
    final c110 = at(r1, g1, b0);
    final c001 = at(r0, g0, b1);
    final c101 = at(r1, g0, b1);
    final c011 = at(r0, g1, b1);
    final c111 = at(r1, g1, b1);

    final c00 = lerp(c000, c100, dr);
    final c10 = lerp(c010, c110, dr);
    final c01 = lerp(c001, c101, dr);
    final c11 = lerp(c011, c111, dr);
    final c0 = lerp(c00, c10, dg);
    final c1 = lerp(c01, c11, dg);
    return lerp(c0, c1, db);
  }
}

_Cube _parseCube(File file) {
  var n = 0;
  final data = <double>[];
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('LUT_3D_SIZE')) {
      n = int.parse(line.split(RegExp(r'\s+')).last);
      continue;
    }
    if (line.startsWith('LUT_1D_SIZE')) {
      throw const FormatException('1D LUTs are not supported');
    }
    if (line.startsWith('TITLE') ||
        line.startsWith('DOMAIN_MIN') ||
        line.startsWith('DOMAIN_MAX')) {
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 3) continue;
    final r = double.tryParse(parts[0]);
    final g = double.tryParse(parts[1]);
    final b = double.tryParse(parts[2]);
    if (r == null || g == null || b == null) continue;
    data..add(r)..add(g)..add(b);
  }
  if (n <= 0 || data.length != n * n * n * 3) {
    throw FormatException('Bad .cube: size=$n values=${data.length}');
  }
  return _Cube(n, data);
}

int _to255(double v) {
  final x = (v * 255.0).round();
  return x < 0 ? 0 : (x > 255 ? 255 : x);
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/cube_to_lut_png.dart <input.cube> <output.png>');
    exitCode = 2;
    return;
  }
  final input = File(args[0]);
  if (!input.existsSync()) {
    stderr.writeln('Not found: ${args[0]}');
    exitCode = 2;
    return;
  }
  final cube = _parseCube(input);
  final image = img.Image(width: _dim, height: _dim);

  for (var py = 0; py < _dim; py++) {
    final tileY = py ~/ _size;
    final g = (py % _size) / (_size - 1);
    for (var px = 0; px < _dim; px++) {
      final tileX = px ~/ _size;
      final r = (px % _size) / (_size - 1);
      final blue = (tileY * _tiles + tileX) / (_tiles * _tiles - 1);
      final c = cube.sample(r, g, blue);
      image.setPixelRgba(px, py, _to255(c[0]), _to255(c[1]), _to255(c[2]), 255);
    }
  }

  final out = File(args[1]);
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('wrote ${out.path} (from ${cube.n}^3 cube)');
}
