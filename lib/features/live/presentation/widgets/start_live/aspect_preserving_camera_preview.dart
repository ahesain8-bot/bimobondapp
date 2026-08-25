import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Full-bleed portrait camera preview that crops without distorting.
///
/// The camera reports its sensor preview in landscape dimensions. The
/// dimensions are swapped for a portrait viewport, then [BoxFit.cover] scales
/// that correctly proportioned surface. Only overflow is cropped.
class AspectPreservingCameraPreview extends StatelessWidget {
  const AspectPreservingCameraPreview({
    super.key,
    required this.controller,
    this.alignment = Alignment.center,
  });

  final CameraController controller;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // Defensive: never render a controller that is not ready. The bloc
    // guarantees state updates before dispose, but a HUD-triggered rebuild
    // could still race a slow teardown on some devices.
    try {
      if (!controller.value.isInitialized ||
          controller.value.previewSize == null) {
        return const ColoredBox(color: Colors.black);
      }
    } catch (_) {
      return const ColoredBox(color: Colors.black);
    }

    final previewSize = controller.value.previewSize!;

    final portraitPreviewSize = Size(previewSize.height, previewSize.width);

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: alignment,
          child: SizedBox(
            width: portraitPreviewSize.width,
            height: portraitPreviewSize.height,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
