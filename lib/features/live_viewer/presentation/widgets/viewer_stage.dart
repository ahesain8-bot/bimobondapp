import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/utils/build_safe_notifier.dart';
import '../../../../core/utils/livekit_participant_match.dart';
import '../../../../core/widgets/stage_tiles.dart';
import '../../data/services/fake_livekit_service.dart' show LiveKitService;
import '../../domain/entities/live_entity.dart';
import '../../domain/repositories/guest_repository.dart';
import 'fallback_media.dart';

/// The video area a viewer sees once more than one person is on stage.
///
/// TikTok-style guest panel: the host remains the large background video while
/// up to three active guests occupy a narrow vertical rail on the right.
/// Each seat renders that participant's real LiveKit track.
class ViewerStage extends StatelessWidget {
  const ViewerStage({
    super.key,
    required this.live,
    required this.guests,
    required this.liveKit,
    this.topInset = 0,
    this.isSelfOnStage = false,
    this.currentUserId,
    this.maxHeight,
  });

  final LiveEntity live;

  /// Everyone publishing right now, from `GET /lives/:id/guests`.
  final List<GuestSummary> guests;

  final LiveKitService liveKit;
  final double topInset;

  /// Whether this device is one of the publishers.
  final bool isSelfOnStage;
  final String? currentUserId;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final heightLimit = math.min(
      (size.height - topInset) * 0.66,
      maxHeight ?? double.infinity,
    );
    final height = math.min(size.width / 0.78, heightLimit);
    final width = size.width;
    final room = liveKit.room;
    final visibleGuests = guests.take(3).toList(growable: false);
    final useGrid =
        live.metadata?['layout']?.toString().toUpperCase() == 'GRID';

    Widget buildStage() => useGrid
        ? _ViewerGridStage(
            live: live,
            guests: visibleGuests,
            room: room,
            height: math.min(width / kStageAspect, heightLimit),
            topInset: topInset,
            isSelfOnStage: isSelfOnStage,
            currentUserId: currentUserId,
          )
        : Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ParticipantVideo(
                      identity: live.hostId,
                      name: live.hostName,
                      avatarUrl: live.hostAvatar,
                      room: room,
                      isLocal: false,
                    ),
                    Positioned(
                      right: 8,
                      top: height * 0.12,
                      bottom: 8,
                      width: math.max(104, width * 0.29),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.48),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Request',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            for (
                              var index = 0;
                              index < visibleGuests.length;
                              index++
                            ) ...[
                              Expanded(
                                child: _StageTile(
                                  highlighted: index == 0,
                                  child: _ParticipantVideo(
                                    identity: visibleGuests[index].userId,
                                    name: visibleGuests[index].displayName,
                                    avatarUrl: visibleGuests[index].avatarUrl,
                                    room: room,
                                    isLocal:
                                        isSelfOnStage &&
                                        visibleGuests[index].userId ==
                                            currentUserId,
                                    isMuted: visibleGuests[index].mutedByHost,
                                    cameraOff:
                                        visibleGuests[index].cameraOffByHost,
                                  ),
                                ),
                              ),
                              if (index != visibleGuests.length - 1)
                                const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    if (room == null) return buildStage();
    // Publishing, unpublishing and camera toggles all arrive as Room
    // notifications from WebRTC callbacks, which know nothing about the
    // frame the framework is in.
    return BuildSafeListenableBuilder(
      listenable: room,
      builder: (_, _) => buildStage(),
    );
  }
}

class _ViewerGridStage extends StatelessWidget {
  const _ViewerGridStage({
    required this.live,
    required this.guests,
    required this.room,
    required this.height,
    required this.topInset,
    required this.isSelfOnStage,
    required this.currentUserId,
  });

  final LiveEntity live;
  final List<GuestSummary> guests;
  final Room? room;
  final double height;
  final double topInset;
  final bool isSelfOnStage;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: height,
          child: StageTiles(
            tiles: [
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
                    isLocal: isSelfOnStage && guest.userId == currentUserId,
                    isMuted: guest.mutedByHost,
                    cameraOff: guest.cameraOffByHost,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.child, this.highlighted = false});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF252527),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF20D9E8)
              : Colors.black.withValues(alpha: 0.72),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
      if (!liveKitParticipantMatches(participant, identity)) continue;
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
