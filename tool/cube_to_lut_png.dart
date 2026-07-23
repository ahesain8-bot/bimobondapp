// =============================================================================
// BACKEND / DASHBOARD — .cube → PNG LUT CONVERSION (SOURCE OF TRUTH)
// =============================================================================
//
// Share this file with backend. Mobile does NOT parse .cube at runtime.
// Dashboard uploads .cube → server MUST convert to PNG → API returns lutUrl
// pointing at that PNG only (never a .cube URL).
//
// WHY THIS MATTERS
// ----------------
// The Android camera grades color by sampling a 512×512 texture in GPUImage
// layout (see LutStore.kt + FaceWarpRenderer applyLut). If conversion uses a
// different tile order, axis order, or size, filters look wrong (washed,
// muddy, neon) even when the PNG is "512×512".
//
// We compared the same Presetpro Classic Chrome .cube:
//   - PNG from THIS script  vs  PNG from current backend lutUrl
//   - Both 512×512, but mean absolute RGB diff ≈ 47.8 (must be ~0)
// So backend conversion must match this script exactly (or call equivalent
// logic in Node/Python/etc. with the SAME math below).
//
// REQUIRED OUTPUT
// ---------------
//   • Format:  PNG, 8-bit RGB (no alpha required; opaque is fine)
//   • Size:    512 × 512 pixels exactly
//   • Layout:  GPUImage / Halide-style 3D LUT unwrap:
//                - 8 × 8 tiles
//                - each tile 64 × 64
//                - = 64³ color cube
//   • Within each tile:
//                - X axis = Red   (0 → 1 left → right)
//                - Y axis = Green (0 → 1 top → bottom)
//   • Tile index (row-major, 0..63) = Blue (0 → 1)
//                blue = (tileY * 8 + tileX) / 63
//   • Input .cube: standard Adobe LUT_3D_SIZE, data order R fastest, then G,
//     then B; trilinear sample when upsampling (e.g. 32³ → 64³).
//
// API CONTRACT (color filters)
// ----------------------------
//   GET /camera-studio/color-filters
//   Each LUT filter must include:
//     "renderType": "lut",
//     "lutUrl": "https://…/something.png"   // PNG only, never .cube
//   Optional: lutAsset (bundled offline filename). Online apply uses lutUrl.
//
// HOW TO RUN THIS REFERENCE TOOL (Flutter/Dart repo)
// --------------------------------------------------
//   dart run tool/cube_to_lut_png.dart "path/to/input.cube" path/to/output.png
//
// Example:
//   dart run tool/cube_to_lut_png.dart \
//     "/path/Presetpro - Classic Chrome.cube" \
//     /tmp/correct.png
//
// SELF-TEST BEFORE ASKING MOBILE TO QA (REQUIRED)
// -----------------------------------------------
// Do NOT ask the app team to test in the camera until YOUR conversion passes
// this check locally. App QA is only for the final “looks good on device”
// step after pixel diff ~0.
//
// Steps:
//   1) Convert the same .cube with THIS script → correct.png
//        dart run tool/cube_to_lut_png.dart "input.cube" correct.png
//   2) Convert the same .cube with YOUR backend (or download lutUrl) → backend.png
//   3) Confirm both are exactly 512 × 512
//   4) Compare pixels — mean absolute RGB diff must be ~0 (e.g. < 1).
//      If the number is large (e.g. ~40+), conversion is WRONG: fix and
//      re-run this self-test yourself. Do not ping mobile yet.
//   5) Only after PASS: update lutUrl / re-upload, then tell mobile the
//      filter is ready for app QA.
//
// Pixel diff script (Python 3 + Pillow):
//
//   python3 - <<'PY'
//   from PIL import Image
//   a = Image.open('correct.png').convert('RGB')
//   b = Image.open('backend.png').convert('RGB')
//   assert a.size == (512, 512) and b.size == (512, 512), a.size
//   pa, pb = list(a.getdata()), list(b.getdata())
//   diffs = []
//   for i in range(0, len(pa), 16):
//       d = (abs(pa[i][0]-pb[i][0]) + abs(pa[i][1]-pb[i][1]) +
//            abs(pa[i][2]-pb[i][2])) / 3
//       diffs.append(d)
//   mean = sum(diffs) / len(diffs)
//   print('mean abs diff =', round(mean, 2))
//   print('PASS' if mean < 1 else 'FAIL — fix conversion and re-test')
//   PY
//
// DO NOT
// ------
//   • Put .cube URLs in lutUrl
//   • Use Hald CLUT, vertical strip, or other layouts
//   • Resize with naive nearest-neighbor without matching axes above
//   • Change tile order / R-G-B mapping without coordinating with mobile
//   • Ask mobile to “just test in the app” before self-test PASS above
//
// This file is the offline reference implementation. Port the algorithm to
// your backend language; keep layout + sampling identical.
// =============================================================================

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
