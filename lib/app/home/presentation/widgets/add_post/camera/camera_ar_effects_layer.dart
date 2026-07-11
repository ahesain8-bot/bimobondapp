import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_image_painter.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effects_catalog.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_detector_service.dart';
import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_face_effect_mapper.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';

class CameraArEffectsLayer extends StatefulWidget {
  const CameraArEffectsLayer({
    super.key,
    required this.cameraState,
    required this.preview,
    required this.faceStream,
    required this.effect,
  });

  final CameraState cameraState;
  final AnalysisPreview preview;
  final Stream<CameraFaceDetectionFrame> faceStream;
  final CameraEffectDefinition effect;

  @override
  State<CameraArEffectsLayer> createState() => _CameraArEffectsLayerState();
}

class _CameraArEffectsLayerState extends State<CameraArEffectsLayer> {
  @override
  void initState() {
    super.initState();
    _preloadAsset();
  }

  @override
  void didUpdateWidget(CameraArEffectsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect.slug != widget.effect.slug) {
      _preloadAsset();
    }
  }

  void _preloadAsset() {
    if (!widget.effect.hasAsset) return;
    CameraEffectAssetLoader.preload(widget.effect.assetUrl).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.effect.requiresFaceDetection) return const SizedBox.shrink();

    return IgnorePointer(
      child: StreamBuilder<SensorConfig>(
        stream: widget.cameraState.sensorConfig$,
        builder: (context, sensorSnapshot) {
          if (!sensorSnapshot.hasData) return const SizedBox.shrink();

          return StreamBuilder<CameraFaceDetectionFrame>(
            stream: widget.faceStream,
            builder: (context, frameSnapshot) {
              if (!frameSnapshot.hasData) return const SizedBox.shrink();

              final frame = frameSnapshot.data!;
              final transform = frame.image.getCanvasTransformation(widget.preview);

              return CustomPaint(
                painter: CameraArEffectsPainter(
                  effect: widget.effect,
                  frame: frame,
                  preview: widget.preview,
                  canvasTransformation: transform,
                ),
                size: Size.infinite,
              );
            },
          );
        },
      ),
    );
  }
}

class CameraArEffectsPainter extends CustomPainter {
  CameraArEffectsPainter({
    required this.effect,
    required this.frame,
    required this.preview,
    this.canvasTransformation,
  });

  final CameraEffectDefinition effect;
  final CameraFaceDetectionFrame frame;
  final AnalysisPreview preview;
  final CanvasTransformation? canvasTransformation;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame.faces.isEmpty) return;

    if (canvasTransformation != null) {
      canvas.save();
      canvas.applyTransformation(canvasTransformation!, size);
    }

    final mapped = CameraFaceEffectMapper.mapForLivePreview(
      faces: frame.faces,
      preview: preview,
      image: frame.image,
    );
    CameraEffectImagePainter.paintArScreenSpace(canvas, mapped, effect);

    if (canvasTransformation != null) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CameraArEffectsPainter oldDelegate) {
    if (oldDelegate.effect != effect) return true;
    if (oldDelegate.frame.image != frame.image) return true;
    if (oldDelegate.frame.faces.length != frame.faces.length) return true;

    for (var i = 0; i < frame.faces.length; i++) {
      final oldFace = oldDelegate.frame.faces[i];
      final face = frame.faces[i];
      if (oldFace.boundingBox != face.boundingBox) return true;
      if (oldFace.landmarks.length != face.landmarks.length) return true;
      for (final entry in face.landmarks.entries) {
        if (oldFace.landmarks[entry.key] != entry.value) return true;
      }
    }

    return false;
  }
}

class CameraScreenEffectsLayer extends StatefulWidget {
  const CameraScreenEffectsLayer({super.key, required this.effect});

  final CameraEffectDefinition effect;

  @override
  State<CameraScreenEffectsLayer> createState() =>
      _CameraScreenEffectsLayerState();
}

class _CameraScreenEffectsLayerState extends State<CameraScreenEffectsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _preloadAsset();
  }

  @override
  void didUpdateWidget(CameraScreenEffectsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effect.slug != widget.effect.slug) {
      _preloadAsset();
    }
  }

  void _preloadAsset() {
    if (!widget.effect.hasAsset) return;
    CameraEffectAssetLoader.preload(widget.effect.assetUrl).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.effect.isScreenEffect) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: CameraScreenEffectsPainter(
              effect: widget.effect,
              progress: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class CameraScreenEffectsPainter extends CustomPainter {
  CameraScreenEffectsPainter({required this.effect, required this.progress});

  final CameraEffectDefinition effect;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    CameraEffectImagePainter.paintScreen(
      canvas,
      size,
      effect,
      progress: progress,
    );
  }

  @override
  bool shouldRepaint(CameraScreenEffectsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.effect != effect;
  }
}
