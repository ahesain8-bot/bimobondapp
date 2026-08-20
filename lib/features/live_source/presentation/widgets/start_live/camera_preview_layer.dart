import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../live/presentation/widgets/start_live/aspect_preserving_camera_preview.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_state.dart';

/// Full-screen camera preview layer.
///
/// Shows the live camera feed when ready, otherwise a black background.
class CameraPreviewLayer extends StatelessWidget {
  const CameraPreviewLayer({super.key});

  @override
  Widget build(BuildContext context) {
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
        return Container(color: Colors.black);
      },
    );
  }
}
