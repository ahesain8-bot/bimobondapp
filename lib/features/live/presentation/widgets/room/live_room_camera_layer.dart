import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import '../start_live/ar_live_camera_preview.dart';
import '../start_live/aspect_preserving_camera_preview.dart';
import 'live_audio_room_stage.dart';
import 'live_room_effects_overlay.dart';

/// Full-bleed preview for the live-room host screen.
///
/// Android AR beauty: keep host FaceWarp visible (transparent) until LiveKit
/// publishes, then show [VideoTrackRenderer] of the same beautified frames.
/// Elsewhere: Flutter camera → LiveKit renderer after publish.
class LiveRoomCameraLayer extends StatelessWidget {
  const LiveRoomCameraLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is LiveRoomOpening && current is LiveRoomOpening) {
          return previous.controller != current.controller ||
              previous.isCameraInitialized != current.isCameraInitialized ||
              previous.isAudioOnly != current.isAudioOnly;
        }
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return true;
        }
        return previous.controller != current.controller ||
            previous.localVideoTrack != current.localVideoTrack ||
            previous.isCameraInitialized != current.isCameraInitialized ||
            previous.isMirrorEnabled != current.isMirrorEnabled ||
            previous.isLivePaused != current.isLivePaused ||
            previous.session.paused != current.session.paused ||
            previous.session.audioOnly != current.session.audioOnly ||
            previous.session.scene.scene != current.session.scene.scene ||
            previous.localScreenShareTrack != current.localScreenShareTrack ||
            previous.selectedEffectId != current.selectedEffectId ||
            previous.isFrontCamera != current.isFrontCamera ||
            previous.isMediaConnected != current.isMediaConnected;
      },
      builder: (context, state) {
        final arBeauty = ArLiveCameraPreview.isSupported;

        if (state is LiveRoomOpening) {
          if (state.isAudioOnly) {
            return const ColoredBox(color: Color(0xFF12121A));
          }
          if (arBeauty) {
            // Host / start-live PlatformView stays underneath (transparent route).
            return const ColoredBox(color: Colors.transparent);
          }
          if (state.isCameraInitialized && state.controller != null) {
            return AspectPreservingCameraPreview(controller: state.controller!);
          }
          return const ColoredBox(color: Colors.black);
        }

        if (state is! LiveRoomReady) {
          return ColoredBox(color: arBeauty ? Colors.transparent : Colors.black);
        }

        if (state.session.isAudioOnly) {
          return LiveAudioRoomStage(
            hostName: state.session.host.displayName,
            hostAvatarUrl: state.session.host.avatarUrl,
            coverUrl: state.session.coverUrl,
            paused: state.isLivePaused,
            speakers: [
              for (final guest in state.activeGuests)
                LiveAudioSpeaker(
                  name: guest.displayName,
                  avatarUrl: guest.avatarUrl,
                  muted: guest.mutedByHost,
                  speaking: !guest.mutedByHost,
                ),
            ],
          );
        }

        // SCREEN publishes the device display to viewers. Rendering that
        // local track here recaptures the live chrome (infinite mirror).
        // Camera stays off; DUAL still shows camera + screen PiP below.
        if (state.session.scene.isScreen) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const _ScreenShareLocalPlaceholder(),
              const LiveRoomColorGradeOverlay(),
              if (state.isLivePaused) const _PausedOverlay(),
            ],
          );
        }

        Widget? preview;
        // Android beauty: always keep host FaceWarp visible (transparent route
        // over the start/post camera). Never switch to a Flutter/LiveKit texture
        // that looks like a second camera.
        if (arBeauty) {
          preview = const ColoredBox(color: Colors.transparent);
        } else if (state.localVideoTrack != null && state.isMediaConnected) {
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
          return ColoredBox(color: arBeauty ? Colors.transparent : Colors.black);
        }

        final screenShare = state.localScreenShareTrack;
        if (screenShare != null && state.session.scene.isDual) {
          // Do not put a local screen-share VideoTrackRenderer on the host
          // canvas. On Android that PlatformView ignores Flutter clips and
          // covers the camera with the captured live chrome (black DUAL).
          // Viewers still receive the published screen track.
          preview = Stack(
            fit: StackFit.expand,
            children: [
              preview,
              const Positioned(
                right: 12,
                bottom: 140,
                width: 120,
                height: 180,
                child: _DualScreenSharePipBadge(),
              ),
            ],
          );
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

class _DualScreenSharePipBadge extends StatelessWidget {
  const _DualScreenSharePipBadge();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: const ColoredBox(
        color: Color(0xFF1C1C24),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.screen_share_outlined, color: Colors.white, size: 28),
                SizedBox(height: 6),
                Text(
                  'Screen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenShareLocalPlaceholder extends StatelessWidget {
  const _ScreenShareLocalPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF12121A),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_share_outlined, color: Colors.white, size: 56),
              SizedBox(height: 12),
              Text(
                'You are sharing your screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
