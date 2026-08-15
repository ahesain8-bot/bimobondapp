import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/effects/live_effects_catalog.dart';
import '../../../domain/entities/live_effect.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import '../../effects/face_coordinate_mapper.dart';
import '../../effects/live_effect_painter.dart';
import '../../effects/live_face_tracker_scope.dart';

/// Draws the selected face-tracked effect beside the camera preview.
///
/// Place as a sibling of [AspectPreservingCameraPreview] inside the same
/// optional host [Transform.flip] ("video mirror" toggle). Front-camera
/// selfie mirroring is handled inside [FaceCoordinateMapper], not here.
class LiveRoomEffectsOverlay extends StatelessWidget {
  const LiveRoomEffectsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return true;
        }
        return previous.selectedEffectId != current.selectedEffectId ||
            previous.controller != current.controller ||
            previous.isCameraInitialized != current.isCameraInitialized ||
            previous.isFrontCamera != current.isFrontCamera;
      },
      builder: (context, state) {
        if (state is! LiveRoomReady ||
            !state.isCameraInitialized ||
            state.controller == null) {
          return const SizedBox.shrink();
        }

        final effect = LiveEffectsCatalog.byId(state.selectedEffectId);
        if (effect.kind == LiveEffectKind.none ||
            effect.kind == LiveEffectKind.colorGrade) {
          return const SizedBox.shrink();
        }

        return _TrackedEffectPaint(
          effect: effect,
          controller: state.controller!,
        );
      },
    );
  }
}

/// Full-screen color grade that does not need face tracking / mirroring sync.
class LiveRoomColorGradeOverlay extends StatelessWidget {
  const LiveRoomColorGradeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return true;
        }
        return previous.selectedEffectId != current.selectedEffectId;
      },
      builder: (context, state) {
        if (state is! LiveRoomReady) return const SizedBox.shrink();
        final effect = LiveEffectsCatalog.byId(state.selectedEffectId);
        if (effect.kind != LiveEffectKind.colorGrade) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: CustomPaint(
            painter: LiveEffectPainter(effect: effect, face: null),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _TrackedEffectPaint extends StatelessWidget {
  const _TrackedEffectPaint({
    required this.effect,
    required this.controller,
  });

  final LiveEffect effect;
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final tracker = LiveFaceTrackerScope.of(context);
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final rawFace = tracker.face;
        return LayoutBuilder(
          builder: (context, constraints) {
            final mapped = rawFace == null
                ? null
                : FaceCoordinateMapper.forPreview(
                    widgetSize: constraints.biggest,
                    face: rawFace,
                    controller: controller,
                  ).mapFace(rawFace);

            return IgnorePointer(
              child: CustomPaint(
                painter: LiveEffectPainter(effect: effect, face: mapped),
                child: const SizedBox.expand(),
              ),
            );
          },
        );
      },
    );
  }
}
