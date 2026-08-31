import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../../core/utils/build_safe_notifier.dart';
import '../../../../../core/utils/livekit_participant_match.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../../../core/widgets/stage_tiles.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_camera_layer.dart';

/// The video area of the host room.
///
/// Alone, the camera stays full-bleed and this adds nothing. As soon as someone
/// else is publishing, the host stays full-size and guests appear in a narrow
/// right-hand rail, matching the product reference for multi-guest LIVE.
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
                  previous.guests != current.guests ||
                  previous.battle != current.battle ||
                  previous.battleMediaRoom != current.battleMediaRoom)),
      builder: (context, state) {
        final guests = state is LiveRoomReady
            ? state.activeGuests
            : const <LiveGuest>[];

        if (state is LiveRoomReady && state.isBattleActive) {
          return _BattleStage(
            battle: state.battle!,
            currentLiveId: state.session.id,
            topInset: topInset,
            battleMediaRoom: state.battleMediaRoom,
          );
        }

        // Nobody else on stage: the camera keeps the whole screen.
        if (guests.isEmpty) return const LiveRoomCameraLayer();

        final size = MediaQuery.sizeOf(context);
        final room = context.read<LiveSessionRepository>().mediaRoom;
        final maxHeight = (size.height - topInset) * 0.66;
        final height = math.min(size.width / 0.78, maxHeight);
        final width = size.width;
        final visibleGuests = guests.take(3).toList(growable: false);
        final railWidth = (width * 0.27).clamp(94.0, 116.0);
        final railTop = math.max(18.0, height * 0.08);
        final seatHeight = math.min(
          railWidth * 1.24,
          math.max(72.0, (height - railTop - 40) / 3),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const LiveRoomCameraLayer(),
                  Positioned(
                    key: const ValueKey('host_tiktok_guest_rail'),
                    right: 6,
                    top: railTop,
                    width: railWidth,
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
                          for (var index = 0; index < 3; index++) ...[
                            SizedBox(
                              key: ValueKey('host_tiktok_guest_seat_$index'),
                              height: seatHeight,
                              child: index < visibleGuests.length
                                  ? _StageTile(
                                      highlighted: index == 0,
                                      child: _GuestVideo(
                                        guest: visibleGuests[index],
                                        room: room is Room ? room : null,
                                      ),
                                    )
                                  : const _EmptyGuestSeat(),
                            ),
                            if (index != 2) const SizedBox(height: 4),
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
      },
    );
  }
}

class _BattleStage extends StatelessWidget {
  const _BattleStage({
    required this.battle,
    required this.currentLiveId,
    required this.topInset,
    required this.battleMediaRoom,
  });

  final LiveBattle battle;
  final String currentLiveId;
  final double topInset;
  final Room? battleMediaRoom;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxHeight = (size.height - topInset) * kStageMaxHeightFactor;
    final height = math.min(size.width / kStageAspect, maxHeight);
    final width = math.min(size.width, height * kStageAspect);
    final room = battleMediaRoom;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(
                    child: _StageTile(child: LiveRoomCameraLayer()),
                  ),
                  const SizedBox(width: kStageTileGap),
                  Expanded(
                    child: _StageTile(
                      child: _OpponentVideo(
                        room: room is Room ? room : null,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _HostBattleBar(
                  leftScore: battle.scoreFor(currentLiveId),
                  rightScore: battle.opponentScoreFor(currentLiveId),
                  endTime: battle.endTime,
                  multiplier: battle.multiplier,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpponentVideo extends StatelessWidget {
  const _OpponentVideo({required this.room});

  final Room? room;

  VideoTrack? get _track {
    final participants = room?.remoteParticipants.values;
    if (participants == null) return null;
    for (final participant in participants) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (publication.subscribed && !publication.muted && track != null) {
          return track;
        }
      }
    }
    return null;
  }

  Widget _content() {
    final track = _track;
    if (track != null) {
      return VideoTrackRenderer(track, fit: VideoViewFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFF17171A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 42, color: Colors.white38),
            SizedBox(height: 8),
            Text(
              'جاري توصيل بث الخصم…',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = room;
    if (value == null) return _content();
    return BuildSafeListenableBuilder(
      listenable: value,
      builder: (_, _) => _content(),
    );
  }
}

class _HostBattleBar extends StatefulWidget {
  const _HostBattleBar({
    required this.leftScore,
    required this.rightScore,
    required this.endTime,
    required this.multiplier,
  });

  final int leftScore;
  final int rightScore;
  final DateTime? endTime;
  final double multiplier;

  @override
  State<_HostBattleBar> createState() => _HostBattleBarState();
}

class _HostBattleBarState extends State<_HostBattleBar> {
  late final Stream<int> _ticks = Stream<int>.periodic(
    const Duration(seconds: 1),
    (value) => value,
  );

  String get _remaining {
    final end = widget.endTime;
    if (end == null) return '--:--';
    final seconds = math.max(0, end.difference(DateTime.now()).inSeconds);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, widget.leftScore + widget.rightScore);
    final left = (widget.leftScore / total * 1000).round().clamp(80, 920);
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Row(
            children: [
              Expanded(
                flex: left,
                child: _score(Color(0xFFFF2D6F), widget.leftScore, false),
              ),
              Expanded(
                flex: 1000 - left,
                child: _score(Color(0xFF22CEDA), widget.rightScore, true),
              ),
            ],
          ),
          Positioned(
            top: 18,
            child: StreamBuilder<int>(
              stream: _ticks,
              builder: (_, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xDD14202A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.multiplier > 1 ? '×${widget.multiplier.toStringAsFixed(1)}  ' : ''}$_remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _score(Color color, int value, bool right) => Container(
    height: 18,
    color: color,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: right ? Alignment.centerRight : Alignment.centerLeft,
    child: Text(
      '$value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
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

class _EmptyGuestSeat extends StatelessWidget {
  const _EmptyGuestSeat();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9262629),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.black.withValues(alpha: 0.7)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.person, size: 42, color: Colors.white30),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 15, color: Color(0xFF161823)),
            ),
          ),
        ],
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
      if (!liveKitParticipantMatches(participant, guest.userId)) continue;
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
