import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';

import '../../../../../core/models/live_media_mode.dart';
import '../../../../../core/models/live_topic.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../data/datasources/lives_remote_datasource.dart';
import '../../../data/mappers/live_session_mapper.dart';
import '../../../domain/entities/live_session.dart';
import '../../bloc/start_live/live_bloc.dart';
import '../../bloc/start_live/live_event.dart';
import '../../bloc/start_live/live_state.dart';
import '../../pages/live_room_page.dart';
import '../live_countdown_overlay.dart';
import 'ar_live_camera_preview.dart';
import 'live_start_topic_schedule.dart';

/// Opens the live room after countdown + camera handoff.
Future<void> openLiveRoomFromStart(
  BuildContext context, {
  required String title,
  LiveBloc? liveBloc,
  String? topic,
  String? existingLiveId,
  String? mediaMode,
}) async {
  final bloc = liveBloc ?? context.read<LiveBloc>();
  final ready = bloc.state is LiveReady ? bloc.state as LiveReady : null;
  final audioMode = mediaMode != null
      ? LiveMediaMode.isAudio(mediaMode: mediaMode)
      : ready?.isAudioMode == true;
  final resolvedTopic = LiveTopic.normalize(topic ?? ready?.topic);
  final resolvedMode = audioMode ? LiveMediaMode.audio : LiveMediaMode.video;
  final useAr = ArLiveCameraPreview.isSupported && !audioMode;
  if (useAr) {
    await ArCameraBridge.setLivePublishingExclusive(true);
  }
  if (!context.mounted) return;

  await LiveCountdownOverlay.run(context);
  if (!context.mounted) {
    if (useAr) {
      await ArCameraBridge.setLivePublishingExclusive(false);
    }
    return;
  }

  CameraController? runningCamera;
  if (audioMode || useAr) {
    // Voice Chat does not hand off a camera. AR keeps Kotlin FaceWarp.
  } else {
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
            pageBuilder: (context, animation, secondaryAnimation) => LiveRoomPage(
              title: title.isEmpty ? null : title,
              initialCamera: null,
              useArBeautyCamera: true,
              mediaMode: resolvedMode,
              topic: resolvedTopic,
              existingLiveId: existingLiveId,
            ),
          )
        : MaterialPageRoute<void>(
            builder: (_) => LiveRoomPage(
              title: title.isEmpty ? null : title,
              initialCamera: audioMode ? null : runningCamera,
              mediaMode: resolvedMode,
              topic: resolvedTopic,
              existingLiveId: existingLiveId,
            ),
          ),
  );

  if (useAr) {
    await ArCameraBridge.setLivePublishingExclusive(false);
  }
  if (!context.mounted) return;
  bloc.add(const LiveAppResumed());
}

Future<bool> createPlannedLiveFromStart({
  required String title,
  required DateTime scheduledAt,
  required bool audioMode,
  String? topic,
}) async {
  if (!scheduledAt.isAfter(DateTime.now())) {
    throw ArgumentError('scheduledAt must be in the future');
  }
  final response = await LivesRemoteDataSource().createPlanned(
    title: title.trim().isEmpty ? 'بث مباشر' : title.trim(),
    scheduledAt: scheduledAt,
    mediaMode: audioMode ? LiveMediaMode.audio : LiveMediaMode.video,
    topic: LiveTopic.normalize(topic),
  );
  final liveMap = (response['live'] as Map<String, dynamic>?) ?? response;
  final session = LiveSessionMapper.fromLiveJson(liveMap);
  return session.isPlanned || session.scheduledAt != null;
}

Future<void> startOrScheduleFromStart(
  BuildContext context, {
  required String title,
  LiveBloc? liveBloc,
  VoidCallback? onPlannedCreated,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final bloc = liveBloc ?? context.read<LiveBloc>();
  final ready = bloc.state is LiveReady ? bloc.state as LiveReady : null;
  final scheduledAt = ready?.scheduledAt;
  final topic = ready?.topic;
  final audioMode = ready?.isAudioMode == true;

  if (scheduledAt != null) {
    await createPlannedLiveFromStart(
      title: title,
      scheduledAt: scheduledAt,
      audioMode: audioMode,
      topic: topic,
    );
    if (!context.mounted) return;
    bloc.add(const LiveScheduleChanged(null));
    onPlannedCreated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.liveScheduledFor(formatLiveSchedule(scheduledAt)),
        ),
      ),
    );
    return;
  }

  await openLiveRoomFromStart(
    context,
    title: title,
    liveBloc: bloc,
    topic: topic,
  );
}

Future<void> startExistingPlannedLiveFromStart(
  BuildContext context, {
  required LiveSession live,
  LiveBloc? liveBloc,
}) async {
  final title = live.title?.trim() ?? '';
  await openLiveRoomFromStart(
    context,
    title: title,
    liveBloc: liveBloc,
    topic: live.topic,
    existingLiveId: live.id,
    mediaMode: live.mediaMode,
  );
}

class LiveContainer extends StatefulWidget {
  const LiveContainer({
    super.key,
    required this.titleController,
    this.onPlannedCreated,
  });

  final TextEditingController titleController;
  final VoidCallback? onPlannedCreated;

  static const Color _tikTokRed = Color(0xFFFE2C55);

  @override
  State<LiveContainer> createState() => _LiveContainerState();
}

class _LiveContainerState extends State<LiveContainer> {
  var _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await startOrScheduleFromStart(
        context,
        title: widget.titleController.text.trim(),
        onPlannedCreated: widget.onPlannedCreated,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.liveCouldNotStartLive}: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: BlocBuilder<LiveBloc, LiveState>(
          buildWhen: (prev, curr) {
            if (prev is! LiveReady || curr is! LiveReady) return true;
            return prev.scheduledAt != curr.scheduledAt;
          },
          builder: (context, state) {
            final scheduled = state is LiveReady && state.scheduledAt != null;
            return ElevatedButton(
              onPressed: _busy ? null : _onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: LiveContainer._tikTokRed,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(
                _busy
                    ? l10n.liveScheduling
                    : scheduled
                    ? l10n.liveScheduleLive
                    : l10n.cameraGoLive,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
