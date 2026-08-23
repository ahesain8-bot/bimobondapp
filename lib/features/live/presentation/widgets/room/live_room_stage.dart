import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../../core/utils/build_safe_notifier.dart';
import '../../../../../core/widgets/stage_tiles.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_camera_layer.dart';

/// The video area of the host room.
///
/// Alone, the camera stays full-bleed and this adds nothing. As soon as someone
/// else is publishing it becomes the shared stage: equal tiles side by side,
/// the host always first, sized to [kStageAspect] so both faces get the same
/// box instead of a guest being squeezed into a thumbnail strip.
class LiveRoomStage extends StatelessWidget {
  const LiveRoomStage({super.key, this.topInset = 0});

  /// Distance from the top of the screen to the bottom of the room header.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          previous.runtimeType != current.runtimeType ||
          (current is LiveRoomReady &&
              (previous is! LiveRoomReady ||
                  previous.guests != current.guests)),
      builder: (context, state) {
        final guests = state is LiveRoomReady
            ? state.activeGuests
            : const <LiveGuest>[];

        // Nobody else on stage: the camera keeps the whole screen.
        if (guests.isEmpty) return const LiveRoomCameraLayer();

        final size = MediaQuery.sizeOf(context);
        final room = context.read<LiveSessionRepository>().mediaRoom;

        // Never taller than the room actually has. On a short phone the
        // reference aspect alone would push the stage under the chat feed and
        // the bars, so height gives way and the box narrows to keep the ratio.
        final maxHeight = (size.height - topInset) * kStageMaxHeightFactor;
        final height = math.min(size.width / kStageAspect, maxHeight);
        final width = math.min(size.width, height * kStageAspect);

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              width: width,
              height: height,
              child: StageTiles(
                tiles: [
                  const _StageTile(child: LiveRoomCameraLayer()),
                  for (final guest in guests)
                    _StageTile(
                      child: _GuestVideo(
                        guest: guest,
                        room: room is Room ? room : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kStageTileRadius),
      child: ColoredBox(
        color: const Color(0xFF101012),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _GuestVideo extends StatelessWidget {
  const _GuestVideo({required this.guest, required this.room});

  final LiveGuest guest;
  final Room? room;

  /// The guest's camera track, if they are publishing one right now.
  VideoTrack? get _track {
    final participants = room?.remoteParticipants.values;
    if (participants == null) return null;
    for (final participant in participants) {
      if (participant.identity != guest.userId) continue;
      for (final publication in participant.videoTrackPublications) {
        if (publication.subscribed && !publication.muted) {
          final track = publication.track;
          if (track != null) return track;
        }
      }
    }
    return null;
  }

  Widget _build(BuildContext context) {
    final track = guest.cameraOffByHost ? null : _track;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (track != null)
          VideoTrackRenderer(track, fit: VideoViewFit.cover)
        else
          _GuestPlaceholder(guest: guest),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _GuestNamePlate(guest: guest),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (room == null) return _build(context);
    // The Room is a ChangeNotifier: a guest publishing, unpublishing or
    // toggling their camera repaints the tile without any polling. Those
    // notifications come off WebRTC/signalling callbacks with no regard for
    // what the framework is doing, so the rebuild has to be build-safe.
    return BuildSafeListenableBuilder(
      listenable: room!,
      builder: (context, _) => _build(context),
    );
  }
}

/// Stand-in while the guest's video is not on screen — either not subscribed
/// yet, or their camera is off.
class _GuestPlaceholder extends StatelessWidget {
  const _GuestPlaceholder({required this.guest});

  final LiveGuest guest;

  @override
  Widget build(BuildContext context) {
    final avatar = guest.avatarUrl;
    if (avatar != null && avatar.isNotEmpty) {
      return Image.network(
        avatar,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _GuestGlyph(),
      );
    }
    return const _GuestGlyph();
  }
}

class _GuestGlyph extends StatelessWidget {
  const _GuestGlyph();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF1A1A1C),
      child: Center(child: Icon(Icons.person, size: 36, color: Colors.white38)),
    );
  }
}

class _GuestNamePlate extends StatelessWidget {
  const _GuestNamePlate({required this.guest});

  final LiveGuest guest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          if (guest.mutedByHost) ...[
            const Icon(Icons.mic_off, size: 12, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              guest.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (guest.role.toUpperCase() == 'CO_HOST') ...[
            const SizedBox(width: 4),
            const Icon(Icons.star, size: 12, color: Color(0xFFFFC107)),
          ],
        ],
      ),
    );
  }
}
