import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_image_painter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/core/utils/video_thumbnail_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// AR effect preview for gallery images and videos (first-frame for video).
class GalleryArEffectsLayer extends StatefulWidget {
  const GalleryArEffectsLayer({
    super.key,
    required this.file,
    required this.isVideo,
    required this.effect,
    required this.mediaSize,
  });

  final File file;
  final bool isVideo;
  final CameraEffectDefinition effect;
  final Size mediaSize;

  @override
  State<GalleryArEffectsLayer> createState() => _GalleryArEffectsLayerState();
}

class _GalleryArEffectsLayerState extends State<GalleryArEffectsLayer> {
  List<Face> _faces = const [];
  Size _faceCoordSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _detectFaces();
  }

  @override
  void didUpdateWidget(GalleryArEffectsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.effect.id != widget.effect.id) {
      _detectFaces();
    }
  }

  Future<void> _detectFaces() async {
    if (!widget.effect.requiresFaceDetection) return;

    var sourcePath = widget.file.path;
    var coordSize = widget.mediaSize;
    File? tempFrame;

    if (widget.isVideo) {
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

    final detector = FaceDetector(
      options: FaceDetectorOptions(enableLandmarks: true),
    );
    try {
      final faces = await detector.processImage(
        InputImage.fromFilePath(sourcePath),
      );
      if (!mounted) return;
      setState(() {
        _faces = faces;
        _faceCoordSize = coordSize;
      });
    } finally {
      await detector.close();
      await VideoThumbnailUtils.deleteIfExists(tempFrame);
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
  });

  final CameraEffectDefinition effect;
  final List<Face> faces;
  final Size mediaSize;
  final Size faceCoordSize;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.cover, faceCoordSize, size);
    final dest = fitted.destination;
    final scale = dest.width / faceCoordSize.width;
    final offset = Offset(
      (size.width - dest.width) / 2,
      (size.height - dest.height) / 2,
    );

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    CameraEffectImagePainter.paintAr(
      canvas,
      faceCoordSize,
      faces,
      effect,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GalleryArEffectsPainter oldDelegate) {
    return oldDelegate.effect != effect ||
        oldDelegate.faces != faces ||
        oldDelegate.mediaSize != mediaSize;
  }
}
