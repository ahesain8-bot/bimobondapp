import 'package:flutter/material.dart';

/// Full-screen camera preview layer.
///
/// UI-only version: always shows a black background (no camera controller).
class CameraPreviewLayer extends StatelessWidget {
  const CameraPreviewLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.black);
  }
}
