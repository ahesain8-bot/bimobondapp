import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_layout_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraLayoutComposer {
  CameraLayoutComposer._();

  static Future<File> compose({
    required CameraLayoutMode mode,
    required List<String> cellPaths,
  }) async {
    const outW = 720;
    const outH = 1280;
    final fracs = mode.cellFractions;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW * 1.0, outH * 1.0),
      Paint()..color = const Color(0xFF000000),
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;

    final count = fracs.length;
    for (var i = 0; i < count && i < cellPaths.length; i++) {
      final f = fracs[i];
      final left = f.$1 * outW;
      final top = f.$2 * outH;
      final dw = f.$3 * outW;
      final dh = f.$4 * outH;
      final dest = Rect.fromLTWH(left, top, dw, dh);

      final bytes = await File(cellPaths[i]).readAsBytes();
      final target = math.max(dw, dh).ceil().clamp(64, 720);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: target,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final src = _coverSrcRect(
        image.width.toDouble(),
        image.height.toDouble(),
        dw / dh,
      );
      canvas.drawImageRect(image, src, dest, paint);
      image.dispose();
    }

    final picture = recorder.endRecording();
    final composed = await picture.toImage(outW, outH);
    final rgba = await composed.toByteData(format: ui.ImageByteFormat.rawRgba);
    composed.dispose();
    if (rgba == null) {
      throw StateError('layout_compose_failed');
    }

    final packed = img.Image.fromBytes(
      width: outW,
      height: outH,
      bytes: rgba.buffer,
      order: img.ChannelOrder.rgba,
    );
    final jpg = img.encodeJpg(packed, quality: 80);

    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/layout_final_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(jpg, flush: false);
    return out;
  }

  static Rect previewFrameForCell({
    required Size screen,
    required Rect cell,
  }) {
    final scale = math.max(cell.width / screen.width, cell.height / screen.height);
    final w = screen.width * scale;
    final h = screen.height * scale;
    return Rect.fromLTWH(
      cell.left + (cell.width - w) / 2,
      cell.top + (cell.height - h) / 2,
      w,
      h,
    );
  }

  static Rect _coverSrcRect(double srcW, double srcH, double targetAspect) {
    final srcAspect = srcW / srcH;
    if (srcAspect > targetAspect) {
      final w = srcH * targetAspect;
      return Rect.fromLTWH((srcW - w) / 2, 0, w, srcH);
    }
    final h = srcW / targetAspect;
    return Rect.fromLTWH(0, (srcH - h) / 2, srcW, h);
  }
}
