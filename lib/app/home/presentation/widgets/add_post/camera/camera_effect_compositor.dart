import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/utils/media_temp_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_image_painter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detection.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/core/utils/native_video_processor.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Bakes preview-only camera effects into captured photos and videos.
class CameraEffectCompositor {
  CameraEffectCompositor._();

  static Future<File> applyIfNeeded({
    required File input,
    required CameraEffectId? effectId,
    required bool isVideo,
  }) async {
    final effect = effectId == null
        ? null
        : CameraEffectsCatalog.byId(effectId);
    if (effect == null || effect.isNone) return input;

    try {
      final File? result;
      if (isVideo) {
        result = await _applyToVideo(input, effect);
      } else {
        result = await _applyToImage(input, effect);
      }
      if (result == null) return input;
      return MediaTempUtils.replaceKeepingOutput(input: input, output: result);
    } catch (e, st) {
      debugPrint('Camera effect compositing failed: $e\n$st');
      return input;
    }
  }

  static Future<File?> _applyToImage(
    File file,
    CameraEffectDefinition effect,
  ) async {
    final bytes = await file.readAsBytes();
    final normalized = CameraCaptureUtils.normalizeImageBytes(bytes);
    final working = normalized ?? bytes;

    final codec = await ui.instantiateImageCodec(working);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final size = Size(width.toDouble(), height.toDouble());

    File? tempDetectFile;
    List<CameraDetectedFace> faces;
    if (normalized != null) {
      final tempDir = await getTemporaryDirectory();
      final detectFile = File(
        '${tempDir.path}/effect_detect_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      tempDetectFile = detectFile;
      await detectFile.writeAsBytes(normalized);
      faces = await _detectFaces(detectFile.path, effect);
    } else {
      faces = await _detectFaces(file.path, effect);
    }
    await VideoThumbnailUtils.deleteIfExists(tempDetectFile);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    if (effect.requiresFaceDetection && faces.isNotEmpty) {
      CameraEffectImagePainter.paintAr(canvas, size, faces, effect);
    }
    if (effect.isScreenEffect) {
      CameraEffectImagePainter.paintScreen(canvas, size, effect);
    }

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(width, height);
    image.dispose();
    picture.dispose();

    final raw = await outImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    outImage.dispose();
    if (raw == null) return null;

    final encoded = img.encodeJpg(
      img.Image.fromBytes(
        width: width,
        height: height,
        bytes: raw.buffer,
        numChannels: 4,
      ),
      quality: 92,
    );

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/effect_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(encoded);
    return outFile;
  }

  static Future<File?> _applyToVideo(
    File file,
    CameraEffectDefinition effect,
  ) async {
    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    final videoWidth = controller.value.size.width.ceil().clamp(1, 4096);
    final videoHeight = controller.value.size.height.ceil().clamp(1, 4096);
    await controller.dispose();

    List<CameraDetectedFace> faces = [];
    int? faceFrameWidth;
    int? faceFrameHeight;
    if (effect.requiresFaceDetection) {
      final frameFile = await VideoThumbnailUtils.generateThumbnailFile(
        file,
        timeMs: 0,
        maxHeight: videoHeight,
      );
      if (frameFile != null) {
        final frameBytes = await frameFile.readAsBytes();
        final codec = await ui.instantiateImageCodec(frameBytes);
        final frame = await codec.getNextFrame();
        faceFrameWidth = frame.image.width;
        faceFrameHeight = frame.image.height;
        frame.image.dispose();

        faces = await _detectFaces(frameFile.path, effect);
        await VideoThumbnailUtils.deleteIfExists(frameFile);
      }
    }

    final overlayFile = await _renderOverlayPng(
      width: videoWidth,
      height: videoHeight,
      effect: effect,
      faces: faces,
      faceCoordWidth: faceFrameWidth,
      faceCoordHeight: faceFrameHeight,
    );

    if (overlayFile == null) return null;

    try {
      final output = await NativeVideoProcessor.overlayImage(
        input: file,
        overlayPng: overlayFile,
      );
      await VideoThumbnailUtils.deleteIfExists(overlayFile);
      return output;
    } catch (e, st) {
      debugPrint('Camera effect native overlay error: $e\n$st');
      await VideoThumbnailUtils.deleteIfExists(overlayFile);
      return null;
    }
  }

  static Future<File?> _renderOverlayPng({
    required int width,
    required int height,
    required CameraEffectDefinition effect,
    required List<CameraDetectedFace> faces,
    int? faceCoordWidth,
    int? faceCoordHeight,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());

    if (effect.requiresFaceDetection && faces.isNotEmpty) {
      final coordW = faceCoordWidth ?? width;
      final coordH = faceCoordHeight ?? height;
      if (coordW != width || coordH != height) {
        canvas.save();
        canvas.scale(width / coordW, height / coordH);
        CameraEffectImagePainter.paintAr(
          canvas,
          Size(coordW.toDouble(), coordH.toDouble()),
          faces,
          effect,
        );
        canvas.restore();
      } else {
        CameraEffectImagePainter.paintAr(canvas, size, faces, effect);
      }
    }
    if (effect.isScreenEffect) {
      CameraEffectImagePainter.paintScreen(canvas, size, effect);
    }

    final picture = recorder.endRecording();
    final overlayImage = await picture.toImage(width, height);
    picture.dispose();

    final bytes = await overlayImage.toByteData(format: ui.ImageByteFormat.png);
    overlayImage.dispose();
    if (bytes == null) return null;

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  static Future<List<CameraDetectedFace>> _detectFaces(
    String path,
    CameraEffectDefinition effect,
  ) async {
    if (!effect.requiresFaceDetection) return const [];
    return CameraFaceDetection.detectFromFilepath(path, accurate: true);
  }
}
