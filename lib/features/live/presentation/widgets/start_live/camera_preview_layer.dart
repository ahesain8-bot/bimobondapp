import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_state.dart';
import 'ar_live_camera_preview.dart';
import 'aspect_preserving_camera_preview.dart';

/// Full-screen camera preview for live start.
///
/// Android: Kotlin AR beauty camera ([ArLiveCameraPreview]).
/// Other platforms: Flutter `camera` plugin preview.
class CameraPreviewLayer extends StatelessWidget {
  const CameraPreviewLayer({super.key});

  @override
  Widget build(BuildContext context) {
    if (ArLiveCameraPreview.isSupported) {
      return BlocBuilder<LiveBloc, LiveState>(
        buildWhen: (previous, current) {
          // Keep PlatformView mounted across brief state flips when possible.
          final a = previous is LiveReady && previous.isCameraInitialized;
          final b = current is LiveReady && current.isCameraInitialized;
          final initA = previous is LiveCameraInitializing;
          final initB = current is LiveCameraInitializing;
          return a != b || initA != initB || previous.runtimeType != current.runtimeType;
        },
        builder: (context, state) {
          // Mount as soon as we leave Initial — PlatformView.init starts CameraX.
          if (state is LiveReady || state is LiveCameraInitializing) {
            return const ArLiveCameraPreview();
          }
          return const ColoredBox(color: Colors.black);
        },
      );
    }

    return BlocBuilder<LiveBloc, LiveState>(
      buildWhen: (previous, current) =>
          previous is! LiveReady ||
          current is! LiveReady ||
          previous.controller != current.controller ||
          previous.isCameraInitialized != current.isCameraInitialized,
      builder: (context, state) {
        final ready = state is LiveReady ? state : null;
        final controller = ready?.controller;
        if (ready != null && ready.isCameraInitialized && controller != null) {
          return AspectPreservingCameraPreview(controller: controller);
        }
        return const ColoredBox(color: Colors.black);
      },
    );
  }
}

