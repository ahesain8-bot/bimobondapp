import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/story_export_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
    );
    return file;
  }
}
