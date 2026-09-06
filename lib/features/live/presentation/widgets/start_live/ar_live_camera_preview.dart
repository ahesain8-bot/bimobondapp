import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bimobondapp/app/ar_camera/ar_camera_preview.dart';

/// Live-start host preview using the same Kotlin AR camera as photo/video.
/// Android only; other platforms fall back to the Flutter camera plugin.
class ArLiveCameraPreview extends StatelessWidget {
  const ArLiveCameraPreview({super.key});

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return const ColoredBox(color: Colors.black);
    }
    // IgnorePointer so Flutter chrome (LIVE button, tools) always receives taps.
    return const ColoredBox(
      color: Colors.black,
      child: IgnorePointer(child: ArCameraPreview()),
    );
  }
}
