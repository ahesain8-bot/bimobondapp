import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/utils/camera_capture_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_detected_face.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_image_painter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detection.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// AR effect preview for gallery images and videos (first-frame for video).
class GalleryArEffectsLayer extends StatefulWidget {
  const GalleryArEffectsLayer({
    super.key,
    required this.file,
    required this.isVideo,
    required this.effect,
    required this.mediaSize,
    this.previewFit = BoxFit.cover,
  });

  final File file;
  final bool isVideo;
  final CameraEffectDefinition effect;
  final Size mediaSize;
  final BoxFit previewFit;

  @override
  State<GalleryArEffectsLayer> createState() => _GalleryArEffectsLayerState();
}

class _GalleryArEffectsLayerState extends State<GalleryArEffectsLayer> {
  List<CameraDetectedFace> _faces = const [];
  Size _faceCoordSize = Size.zero;

  @override
  void initState() {
    super.initState();
    if (widget.effect.hasAsset) {
      unawaited(CameraEffectAssetLoader.preload(widget.effect.assetUrl));
    }
    _detectFaces();
  }

  @override
  void didUpdateWidget(GalleryArEffectsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.effect.slug != widget.effect.slug) {
      _detectFaces();
    }
  }

  Future<void> _detectFaces() async {
    if (!widget.effect.requiresFaceDetection) return;

    var sourcePath = widget.file.path;
    var coordSize = widget.mediaSize;
    File? tempFrame;
    File? tempNormalized;

    if (!widget.isVideo) {
      final bytes = await widget.file.readAsBytes();
      final normalized = CameraCaptureUtils.normalizeImageBytes(bytes);
      if (normalized != null) {
        final tempDir = await getTemporaryDirectory();
        tempNormalized = File(
          '${tempDir.path}/gallery_detect_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempNormalized.writeAsBytes(normalized);
        sourcePath = tempNormalized.path;
        final decoded = CameraCaptureUtils.decodeNormalized(normalized);
        if (decoded != null) {
          coordSize = Size(
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          );
        }
      }
    } else if (widget.isVideo) {
      tempFrame = await VideoThumbnailUtils.generateThumbnailFile(
        widget.file,
        timeMs: 0,
        maxHeight: widget.mediaSize.height.ceil(),
      );
      if (tempFrame == null) return;
      sourcePath = tempFrame.path;
      final bytes = await tempFrame.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      coordSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
    }

    try {
      final faces = await CameraFaceDetection.detectFromFilepath(
        sourcePath,
        accurate: true,
      );
      if (!mounted) return;
      setState(() {
        _faces = faces;
        _faceCoordSize = coordSize;
      });
    } finally {
      await VideoThumbnailUtils.deleteIfExists(tempFrame);
      await VideoThumbnailUtils.deleteIfExists(tempNormalized);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_faces.isEmpty || _faceCoordSize == Size.zero) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: _GalleryArEffectsPainter(
          effect: widget.effect,
          faces: _faces,
          mediaSize: widget.mediaSize,
          faceCoordSize: _faceCoordSize,
          previewFit: widget.previewFit,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _GalleryArEffectsPainter extends CustomPainter {
  _GalleryArEffectsPainter({
    required this.effect,
    required this.faces,
    required this.mediaSize,
    required this.faceCoordSize,
    required this.previewFit,
  });

  final CameraEffectDefinition effect;
  final List<CameraDetectedFace> faces;
  final Size mediaSize;
  final Size faceCoordSize;
  final BoxFit previewFit;

  @override
  void paint(Canvas canvas, Size size) {
    final mapped = CameraFaceEffectMapper.mapForBoxFit(
      faces: faces,
      imageSize: faceCoordSize,
      canvasSize: size,
      fit: previewFit,
    );
    CameraEffectImagePainter.paintArScreenSpace(canvas, mapped, effect);
  }

  @override
  bool shouldRepaint(_GalleryArEffectsPainter oldDelegate) {
    return oldDelegate.effect != effect ||
        oldDelegate.faces != faces ||
        oldDelegate.mediaSize != mediaSize;
  }
}
