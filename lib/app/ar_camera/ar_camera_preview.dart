import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bimobondapp/app/ar_camera/ar_camera_constants.dart';

class ArCameraPreview extends StatefulWidget {
  const ArCameraPreview({super.key});

  @override
  State<ArCameraPreview> createState() => _ArCameraPreviewState();
}

class _ArCameraPreviewState extends State<ArCameraPreview> {
  bool _mountNativeView = false;

  @override
  void initState() {
    super.initState();
    // Paint the screen chrome first, then mount the heavy PlatformView.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _mountNativeView = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('AR camera: Android only (Phase 1)'));
    }

    if (!_mountNativeView) {
      return const ColoredBox(color: Colors.black);
    }

    return const AndroidView(
      viewType: ArCameraConstants.viewType,
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
