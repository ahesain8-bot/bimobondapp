import 'dart:io';

import 'package:image/image.dart' as img;

/// Makes edge-connected near-black / near-white pixels transparent.
Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args.first
      : 'assets/images/marketplace/hero_building.png';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('File not found: $path');
    exit(1);
  }

  final bytes = await file.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    stderr.writeln('Could not decode image: $path');
    exit(1);
  }

  final image = decoded.convert(numChannels: 4);
  _floodClearBackground(image);
  await file.writeAsBytes(img.encodePng(image));
  stdout.writeln('Updated $path (${file.lengthSync()} bytes)');
}

bool _isBackgroundPixel(img.Pixel pixel) {
  final r = pixel.r;
  final g = pixel.g;
  final b = pixel.b;
  final maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
  final brightness = (r + g + b) / 3;

  // Solid black / very dark backgrounds from remove-bg exports.
  if (maxC <= 28 && brightness <= 24) return true;

  // White / light gray checkerboard remnants.
  if (minC >= 230 && maxC >= 245) return true;

  // Neutral gray backdrop.
  if (maxC - minC <= 12 && brightness >= 180 && brightness <= 245) {
    return true;
  }

  return false;
}

void _floodClearBackground(img.Image image) {
  final visited = List.generate(
    image.height,
    (_) => List<bool>.filled(image.width, false),
  );
  final queue = <(int x, int y)>[];

  void seed(int x, int y) {
    if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;
    if (visited[y][x]) return;
    if (!_isBackgroundPixel(image.getPixel(x, y))) return;
    visited[y][x] = true;
    queue.add((x, y));
  }

  for (var x = 0; x < image.width; x++) {
    seed(x, 0);
    seed(x, image.height - 1);
  }
  for (var y = 0; y < image.height; y++) {
    seed(0, y);
    seed(image.width - 1, y);
  }

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeLast();
    image.setPixelRgba(x, y, 0, 0, 0, 0);
    seed(x + 1, y);
    seed(x - 1, y);
    seed(x, y + 1);
    seed(x, y - 1);
  }
}
