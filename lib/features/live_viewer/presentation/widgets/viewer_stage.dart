import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/utils/build_safe_notifier.dart';
import '../../../../core/widgets/stage_tiles.dart';
import '../../data/services/fake_livekit_service.dart' show LiveKitService;
import '../../domain/entities/live_entity.dart';
import '../../domain/repositories/guest_repository.dart';
import 'fallback_media.dart';

/// The video area a viewer sees once more than one person is on stage.
///
/// Same split as the host room: equal tiles, host first, at the reference
/// aspect. Each tile renders that participant's real LiveKit track — the grid
/// this replaced drew avatars, so a co-host looked like a static picture.
class ViewerStage extends StatelessWidget {
  const ViewerStage({
    super.key,
    required this.live,
    required this.guests,
    required this.liveKit,
    this.topInset = 0,
    this.isSelfOnStage = false,
    this.currentUserId,
  });

  final LiveEntity live;

  /// Everyone publishing right now, from `GET /lives/:id/guests`.
  final List<GuestSummary> guests;

  final LiveKitService liveKit;
  final double topInset;

  /// Whether this device is one of the publishers.
  final bool isSelfOnStage;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxHeight = (size.height - topInset) * kStageMaxHeightFactor;
    final height = math.min(size.width / kStageAspect, maxHeight);
    final width = math.min(size.width, height * kStageAspect);
    final room = liveKit.room;

    final tiles = <Widget>[
      _StageTile(
        child: _ParticipantVideo(
          identity: live.hostId,
          name: live.hostName,
          avatarUrl: live.hostAvatar,
          room: room,
          isLocal: false,
        ),
      ),
      for (final guest in guests)
        _StageTile(
          child: _ParticipantVideo(
            identity: guest.userId,
            name: guest.displayName,
            avatarUrl: guest.avatarUrl,
            room: room,
            // Your own camera comes off the local participant, not a
            // subscription — nobody subscribes to themselves.
            isLocal: isSelfOnStage && guest.userId == currentUserId,
            isMuted: guest.mutedByHost,
            cameraOff: guest.cameraOffByHost,
          ),
        ),
    ];

    final stage = Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          width: width,
          height: height,
          child: StageTiles(tiles: tiles),
        ),
      ),
    );

    if (room == null) return stage;
    // Publishing, unpublishing and camera toggles all arrive as Room
    // notifications from WebRTC callbacks, which know nothing about the
    // frame the framework is in.
    return BuildSafeListenableBuilder(
      listenable: room,
      builder: (_, _) => stage,
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

class _ParticipantVideo extends StatelessWidget {
  const _ParticipantVideo({
    required this.identity,
    required this.name,
    required this.avatarUrl,
    required this.room,
    required this.isLocal,
    this.isMuted = false,
    this.cameraOff = false,
  });

  final String identity;
  final String name;
  final String? avatarUrl;
  final Room? room;
  final bool isLocal;
  final bool isMuted;
  final bool cameraOff;

  VideoTrack? get _track {
    final current = room;
    if (current == null) return null;

    if (isLocal) {
      for (final pub
          in current.localParticipant?.videoTrackPublications ??
              const <LocalTrackPublication<LocalVideoTrack>>[]) {
        if (!pub.muted && pub.track != null) return pub.track;
      }
      return null;
    }

    for (final participant in current.remoteParticipants.values) {
      if (participant.identity != identity) continue;
      for (final pub in participant.videoTrackPublications) {
        if (pub.subscribed && !pub.muted && pub.track != null) {
          return pub.track;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final track = cameraOff ? null : _track;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (track != null)
          VideoTrackRenderer(track, fit: VideoViewFit.cover)
        else
          FallbackAvatar(seed: identity, name: name, radius: 28),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _NamePlate(name: name, isMuted: isMuted, isLocal: isLocal),
        ),
      ],
    );
  }
}

class _NamePlate extends StatelessWidget {
  const _NamePlate({
    required this.name,
    required this.isMuted,
    required this.isLocal,
  });

  final String name;
  final bool isMuted;
  final bool isLocal;

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
          if (isMuted) ...[
            const Icon(Icons.mic_off, size: 12, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              isLocal ? 'أنت' : name,
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
        ],
      ),
    );
  }
}
