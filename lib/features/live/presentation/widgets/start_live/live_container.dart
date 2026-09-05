import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';

import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';
import '../../pages/live_room_page.dart';
import '../live_countdown_overlay.dart';
import 'ar_live_camera_preview.dart';

/// Opens the live room after countdown + camera handoff.
Future<void> openLiveRoomFromStart(
  BuildContext context, {
  required String title,
  LiveBloc? liveBloc,
}) async {
  final useAr = ArLiveCameraPreview.isSupported;
  if (useAr) {
    await ArCameraBridge.setLivePublishingExclusive(true);
  }

  await LiveCountdownOverlay.run(context);
  if (!context.mounted) {
    if (useAr) {
      await ArCameraBridge.setLivePublishingExclusive(false);
    }
    return;
  }

  final bloc = liveBloc ?? context.read<LiveBloc>();

  CameraController? runningCamera;
  if (useAr) {
    // Keep Kotlin FaceWarp / CameraX running.
  } else {
    final ready = bloc.state is LiveReady ? bloc.state as LiveReady : null;
    runningCamera = (ready != null && ready.isCameraInitialized)
        ? ready.controller
        : null;

    if (runningCamera != null) {
      bloc.add(const LiveCameraHandedOff());
    } else {
      bloc.add(const LiveAppPaused());
    }
  }
  if (!context.mounted) {
    if (useAr) {
      await ArCameraBridge.setLivePublishingExclusive(false);
    }
    return;
  }

  await Navigator.of(context).push(
    useAr
        ? PageRouteBuilder<void>(
            opaque: false,
            barrierColor: Colors.transparent,
            pageBuilder: (_, __, ___) => LiveRoomPage(
              title: title.isEmpty ? null : title,
              initialCamera: null,
              useArBeautyCamera: true,
            ),
          )
        : MaterialPageRoute<void>(
            builder: (_) => LiveRoomPage(
              title: title.isEmpty ? null : title,
              initialCamera: runningCamera,
            ),
          ),
  );

  if (useAr) {
    await ArCameraBridge.setLivePublishingExclusive(false);
  }
  if (!context.mounted) return;
  bloc.add(const LiveAppResumed());
}

/// TikTok red pill **Go LIVE** CTA.
class LiveContainer extends StatelessWidget {
  const LiveContainer({super.key, required this.titleController});

  final TextEditingController titleController;

  static const Color _tikTokRed = Color(0xFFFE2C55);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => openLiveRoomFromStart(
            context,
            title: titleController.text.trim(),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _tikTokRed,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: const Text(
            'Go LIVE',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
