import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import '../start_live/aspect_preserving_camera_preview.dart';
import 'live_room_effects_overlay.dart';

/// Full-bleed preview for the live-room host screen.
///
/// Shows Flutter [CameraController] as soon as [LiveRoomOpening] / early
/// [LiveRoomReady], then switches to LiveKit [VideoTrackRenderer] after publish.
class LiveRoomCameraLayer extends StatelessWidget {
  const LiveRoomCameraLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is LiveRoomOpening && current is LiveRoomOpening) {
          return previous.controller != current.controller ||
              previous.isCameraInitialized != current.isCameraInitialized;
        }
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return true;
        }
        return previous.controller != current.controller ||
            previous.localVideoTrack != current.localVideoTrack ||
            previous.isCameraInitialized != current.isCameraInitialized ||
            previous.isMirrorEnabled != current.isMirrorEnabled ||
            previous.isLivePaused != current.isLivePaused ||
            previous.selectedEffectId != current.selectedEffectId ||
            previous.isFrontCamera != current.isFrontCamera ||
            previous.isMediaConnected != current.isMediaConnected;
      },
      builder: (context, state) {
        if (state is LiveRoomOpening) {
          if (state.isCameraInitialized && state.controller != null) {
            return AspectPreservingCameraPreview(controller: state.controller!);
          }
          return const ColoredBox(color: Colors.black);
        }

        if (state is! LiveRoomReady) {
          return const ColoredBox(color: Colors.black);
        }

        Widget? preview;
        if (state.localVideoTrack != null && state.isMediaConnected) {
          preview = VideoTrackRenderer(
            state.localVideoTrack!,
            fit: VideoViewFit.cover,
          );
        } else if (state.isCameraInitialized && state.controller != null) {
          preview = Stack(
            fit: StackFit.expand,
            children: [
              AspectPreservingCameraPreview(controller: state.controller!),
              const LiveRoomEffectsOverlay(),
            ],
          );
        }

        if (preview == null) {
          return const ColoredBox(color: Colors.black);
        }

        if (state.isMirrorEnabled) {
          preview = Transform.flip(flipX: true, child: preview);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            preview,
            const LiveRoomColorGradeOverlay(),
            if (state.isLivePaused) const _PausedOverlay(),
          ],
        );
      },
    );
  }
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle_filled, color: Colors.white, size: 64),
            SizedBox(height: 8),
            Text(
              'البث متوقف مؤقتًا',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
