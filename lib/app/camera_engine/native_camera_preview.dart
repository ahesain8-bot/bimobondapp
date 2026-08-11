import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Flutter [Texture] fed by CameraX → GPU filter → TextureRegistry.
///
/// Rebuilds only when [NativeCameraController] notifies (flip / start) —
/// filter intensity changes do not recreate the Texture.
class NativeCameraPreview extends StatelessWidget {
  const NativeCameraPreview({
    required this.controller,
    super.key,
    this.fit = BoxFit.cover,
  });

  final NativeCameraController controller;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Native camera: Android only',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final textureId = state.textureId;
        if (textureId == null) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          );
        }

        // Keep Texture identity stable across filter intensity updates.
        Widget texture = Texture(
          key: ValueKey(textureId),
          textureId: textureId,
        );
        if (state.isFront) {
          texture = Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
            child: texture,
          );
        }

        return ColoredBox(
          color: Colors.black,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: 1080,
                    height: 1920,
                    child: texture,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
