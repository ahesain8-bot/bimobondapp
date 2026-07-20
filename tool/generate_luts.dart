// Generates 512x512 PNG "lookup" LUTs (GPUImage layout: 8x8 tiles of 64x64,
// i.e. a 64x64x64 cube) for each color grade, by applying the grade's 4x5
// color matrix to a neutral identity lookup.
//
// These PNGs are the SINGLE source of truth for the color grades: the native
// OpenGL renderer (live camera) and the CPU baker (captured photos) both sample
// them. To make a filter more professional later, just replace its PNG with a
// designer-made LUT (exported from Lightroom/Photoshop as a .cube -> PNG) — no
// code change needed.
//
// Run once (regenerate whenever a matrix below changes):
//   dart run tool/generate_luts.dart
//
// The sampling here MUST match the GLSL `applyLut()` in FaceWarpRenderer.kt and
// the CPU sampler in LutStore.kt.
import 'dart:io';

import 'package:image/image.dart' as img;

/// 4x5 row-major color matrix. Each row = [r, g, b, a, offset] where offset is
/// on the 0..255 scale (same convention as Android ColorMatrix / the bundled
/// catalog). Keep these in sync with ArColorGradeBaker.kt.
const Map<String, List<double>> _matrices = {
  'whitening': [
    1.12, 0.02, 0.02, 0, 12, //
    0.02, 1.10, 0.02, 0, 10, //
    0.02, 0.02, 1.08, 0, 8, //
    0, 0, 0, 1, 0, //
  ],
  'warm': [
    1.16, 0.08, 0.00, 0, 12, //
    0.04, 1.06, 0.00, 0, 6, //
    -0.04, -0.02, 0.94, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  'mono': [
    0.33, 0.59, 0.08, 0, 0, //
    0.33, 0.59, 0.08, 0, 0, //
    0.33, 0.59, 0.08, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  'cool': [
    0.94, 0.00, 0.06, 0, 0, //
    0.00, 1.02, 0.06, 0, 4, //
    0.04, 0.04, 1.18, 0, 10, //
    0, 0, 0, 1, 0, //
  ],
  'vintage': [
    0.95, 0.10, 0.05, 0, 8, //
    0.05, 0.90, 0.05, 0, 4, //
    0.05, 0.10, 0.78, 0, 0, //
    0, 0, 0, 1, 0, //
  ],
  'rosy': [
    1.14, 0.04, 0.04, 0, 10, //
    0.02, 0.98, 0.02, 0, 4, //
    0.06, 0.02, 1.02, 0, 8, //
    0, 0, 0, 1, 0, //
  ],
  'clarendon': [
    1.15, -0.04, 0.04, 0, 8, //
    -0.02, 1.12, 0.02, 0, 4, //
    0.02, -0.06, 1.20, 0, 6, //
    0, 0, 0, 1, 0, //
  ],
  'valencia': [
    1.18, 0.06, -0.02, 0, 14, //
    0.04, 1.06, -0.02, 0, 8, //
    -0.04, 0.00, 0.96, 0, 2, //
    0, 0, 0, 1, 0, //
  ],
  'ludwig': [
    1.05, 0.02, 0.00, 0, 6, //
    0.00, 1.08, 0.02, 0, 4, //
    0.00, 0.00, 1.12, 0, 8, //
    0, 0, 0, 1, 0, //
  ],
};

const int _tiles = 8; // 8x8 tiles
const int _size = 64; // 64 levels per channel
const int _dim = _tiles * _size; // 512

double _clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v);

void main() {
  final outDir = Directory('assets/luts');
  outDir.createSync(recursive: true);

  for (final entry in _matrices.entries) {
    final m = entry.value;
    final image = img.Image(width: _dim, height: _dim);

    for (var py = 0; py < _dim; py++) {
      final tileY = py ~/ _size;
      final g = (py % _size) / (_size - 1); // 0..1
      for (var px = 0; px < _dim; px++) {
        final tileX = px ~/ _size;
        final r = (px % _size) / (_size - 1); // 0..1
        final blue = (tileY * _tiles + tileX) / (_tiles * _tiles - 1); // 0..1

        final r255 = r * 255.0;
        final g255 = g * 255.0;
        final b255 = blue * 255.0;

        final nr = _clamp255(m[0] * r255 + m[1] * g255 + m[2] * b255 + m[4]);
        final ng = _clamp255(m[5] * r255 + m[6] * g255 + m[7] * b255 + m[9]);
        final nb =
            _clamp255(m[10] * r255 + m[11] * g255 + m[12] * b255 + m[14]);

        image.setPixelRgba(px, py, nr.round(), ng.round(), nb.round(), 255);
      }
    }

    final file = File('${outDir.path}/${entry.key}.png');
    file.writeAsBytesSync(img.encodePng(image));
    stdout.writeln('wrote ${file.path}');
  }
  stdout.writeln('Done: ${_matrices.length} LUTs.');
}
