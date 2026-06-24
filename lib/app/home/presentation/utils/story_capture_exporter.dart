import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class StoryCaptureExporter {
  StoryCaptureExporter._();

  static Future<File?> exportFromBoundary({
    required GlobalKey boundaryKey,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 2);
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return null;

    final encoded = img.encodeJpg(
      img.Image.fromBytes(
        width: width,
        height: height,
        bytes: byteData.buffer,
        numChannels: 4,
      ),
      quality: 92,
    );

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/story_export_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(encoded);
    return file;
  }
}
