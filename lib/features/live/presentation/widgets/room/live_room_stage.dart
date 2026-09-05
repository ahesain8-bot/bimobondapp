import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../../app/ar_camera/ar_camera_bridge.dart';
import '../../../../../core/utils/build_safe_notifier.dart';
import '../../../../../core/utils/livekit_participant_match.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../../../core/widgets/pk_battle_start_overlay.dart';
import '../../../../../core/widgets/safe_network_image.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import '../../../../live_viewer/presentation/widgets/tiktok_live_chrome.dart';
import '../start_live/ar_live_camera_preview.dart';
import '../start_live/aspect_preserving_camera_preview.dart';
import 'live_room_camera_layer.dart';

/// TikTok PK box: slightly wider than tall, claims more of the screen than
/// multi-guest so both faces stay large like the Match reference.
const double _kBattleAspect = 1.05;
const double _kBattleMaxHeightFactor = 0.58;

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
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (current is! LiveRoomReady || previous is! LiveRoomReady) {
          return true;
        }
        // Score ticks must not rebuild VideoTrackRenderer tiles.
        final prevBattle = previous.battle;
        final currBattle = current.battle;
        final battleLayoutChanged =
            (prevBattle?.isActive == true) != (currBattle?.isActive == true) ||
            prevBattle?.id != currBattle?.id ||
            prevBattle?.live1Id != currBattle?.live1Id ||
            prevBattle?.live2Id != currBattle?.live2Id ||
            prevBattle?.status != currBattle?.status ||
            prevBattle?.phase != currBattle?.phase;
        return previous.guests != current.guests ||
            battleLayoutChanged ||
            previous.battleMediaRoom != current.battleMediaRoom ||
            previous.topGifterAvatars != current.topGifterAvatars ||
            previous.opponentTopGifterAvatars !=
                current.opponentTopGifterAvatars;
      },
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
            supporters: state.topGifterAvatars,
            opponentSupporters: state.opponentTopGifterAvatars,
            hostAvatarUrl: state.session.host.avatarUrl,
            opponentAvatarUrl: state.pendingCompetitionRequest?.avatarUrl,
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

class _BattleStage extends StatefulWidget {
  const _BattleStage({
    required this.battle,
    required this.currentLiveId,
    required this.topInset,
    required this.battleMediaRoom,
    required this.supporters,
    required this.opponentSupporters,
    this.hostAvatarUrl,
    this.opponentAvatarUrl,
  });

  final LiveBattle battle;
  final String currentLiveId;
  final double topInset;
  final Room? battleMediaRoom;
  final List<String> supporters;
  final List<String> opponentSupporters;
  final String? hostAvatarUrl;
  final String? opponentAvatarUrl;

  @override
  State<_BattleStage> createState() => _BattleStageState();
}

class _BattleStageState extends State<_BattleStage> {
  String? _playedStartForBattleId;
  var _showStartOverlay = false;

  @override
  void initState() {
    super.initState();
    _maybePlayStart(widget.battle, notify: false);
    _syncArPreviewHidden(true);
  }

  @override
  void dispose() {
    _syncArPreviewHidden(false);
    super.dispose();
  }

  void _syncArPreviewHidden(bool hidden) {
    if (!ArLiveCameraPreview.isSupported) return;
    ArCameraBridge.setLocalPreviewHidden(hidden);
  }

  @override
  void didUpdateWidget(covariant _BattleStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.battle.id != widget.battle.id) {
      _maybePlayStart(widget.battle, notify: true);
    }
  }

  void _maybePlayStart(LiveBattle battle, {required bool notify}) {
    if (!battle.isActive) return;
    if (_playedStartForBattleId == battle.id) return;
    final startedAt = battle.startTime;
    // Skip replay when rejoining a battle that has already been running.
    if (startedAt != null &&
        DateTime.now().difference(startedAt).inSeconds > 10) {
      _playedStartForBattleId = battle.id;
      return;
    }
    _playedStartForBattleId = battle.id;
    _showStartOverlay = true;
    if (notify) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final battle = widget.battle;
    final currentLiveId = widget.currentLiveId;
    final topInset = widget.topInset;
    final size = MediaQuery.sizeOf(context);
    final maxHeight = (size.height - topInset) * _kBattleMaxHeightFactor;
    final height = math.min(size.width / _kBattleAspect, maxHeight);
    final width = math.min(size.width, height * _kBattleAspect);
    final room = widget.battleMediaRoom;

    // Opaque fill hides the full-screen Android FaceWarp surface outside the
    // PK box so "my camera" only appears inside the left battle frame.
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0B0B0D)),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: RepaintBoundary(
                                key: const ValueKey('host_pk_self_video'),
                                child: _BattleFeedTile(
                                  child: _HostBattleVideo(
                                    avatarUrl: widget.hostAvatarUrl,
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1.5, color: Colors.black),
                            Expanded(
                              child: RepaintBoundary(
                                key: const ValueKey('host_pk_opponent_video'),
                                child: _BattleFeedTile(
                                  child: _OpponentVideo(
                                    room: room is Room ? room : null,
                                    avatarUrl: widget.opponentAvatarUrl,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: BlocBuilder<LiveRoomBloc, LiveRoomState>(
                            buildWhen: (previous, current) {
                              if (previous is! LiveRoomReady ||
                                  current is! LiveRoomReady) {
                                return previous.runtimeType !=
                                    current.runtimeType;
                              }
                              final prev = previous.battle;
                              final curr = current.battle;
                              if (prev == null || curr == null) {
                                return prev != curr;
                              }
                              return prev.live1Score != curr.live1Score ||
                                  prev.live2Score != curr.live2Score ||
                                  prev.endTime != curr.endTime ||
                                  prev.multiplier != curr.multiplier ||
                                  prev.winnerLiveId != curr.winnerLiveId ||
                                  prev.phase != curr.phase;
                            },
                            builder: (context, state) {
                              final active = state is LiveRoomReady
                                  ? state.battle
                                  : null;
                              final b = active ?? battle;
                              return _HostBattleChrome(
                                leftScore: b.scoreFor(currentLiveId),
                                rightScore: b.opponentScoreFor(currentLiveId),
                                endTime: b.endTime,
                                multiplier: b.multiplier,
                                winnerLiveId: b.winnerLiveId,
                                currentLiveId: currentLiveId,
                              );
                            },
                          ),
                        ),
                        if (_showStartOverlay)
                          Positioned.fill(
                            child: PkBattleStartOverlay(
                              leftAvatarUrl: widget.hostAvatarUrl,
                              rightAvatarUrl: widget.opponentAvatarUrl,
                              onFinished: () {
                                if (!mounted) return;
                                setState(() => _showStartOverlay = false);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: _BattleSupporters(
                              avatars: widget.supporters,
                              isOwnSide: true,
                            ),
                          ),
                          Expanded(
                            child: _BattleSupporters(
                              avatars: widget.opponentSupporters,
                              isOwnSide: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Host half of a PK battle — clipped live camera (LiveKit local / beauty
/// track). Avatar only if the track is not published yet.
class _HostBattleVideo extends StatelessWidget {
  const _HostBattleVideo({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) {
        if (previous is! LiveRoomReady || current is! LiveRoomReady) {
          return previous.runtimeType != current.runtimeType;
        }
        return previous.localVideoTrack != current.localVideoTrack ||
            previous.isMediaConnected != current.isMediaConnected ||
            previous.isMirrorEnabled != current.isMirrorEnabled ||
            previous.isLivePaused != current.isLivePaused ||
            previous.isFrontCamera != current.isFrontCamera;
      },
      builder: (context, state) {
        if (state is! LiveRoomReady) {
          return _BattleAvatarFallback(avatarUrl: avatarUrl);
        }

        // Prefer state track; fall back to the media datasource (AR beauty
        // used to keep state.localVideoTrack null for full-screen FaceWarp).
        final track =
            state.localVideoTrack ??
            context.read<LiveSessionRepository>().localPreviewTrack
                as VideoTrack?;

        Widget child;
        if (track != null) {
          // Stable key keeps the LiveKit texture attached across parent
          // rebuilds — recreating it every score tick is the PK stutter.
          child = RepaintBoundary(
            child: VideoTrackRenderer(
              track,
              key: ValueKey('pk-host-${track.sid ?? track.hashCode}'),
              fit: VideoViewFit.cover,
            ),
          );
          // Front camera preview matches the host's mirrored full-screen look.
          if (state.isMirrorEnabled || state.isFrontCamera) {
            child = Transform.flip(flipX: true, child: child);
          }
        } else if (state.isCameraInitialized && state.controller != null) {
          child = AspectPreservingCameraPreview(controller: state.controller!);
          if (state.isMirrorEnabled || state.isFrontCamera) {
            child = Transform.flip(flipX: true, child: child);
          }
        } else {
          child = _BattleAvatarFallback(avatarUrl: avatarUrl);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(child: child),
            if (state.isLivePaused)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: Icon(Icons.pause_circle_filled, color: Colors.white70, size: 40),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BattleAvatarFallback extends StatelessWidget {
  const _BattleAvatarFallback({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (isValidNetworkImageUrl(avatarUrl)) {
      return SafeNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        blankOnError: true,
        showLoadingIndicator: false,
      );
    }
    return const ColoredBox(
      color: Color(0xFF17171A),
      child: Center(
        child: Icon(Icons.person, size: 48, color: Colors.white38),
      ),
    );
  }
}

/// Full-bleed feed tile (no rounded card) — TikTok Match style.
class _BattleFeedTile extends StatelessWidget {
  const _BattleFeedTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF121214),
      child: SizedBox.expand(child: child),
    );
  }
}

class _HostBattleChrome extends StatelessWidget {
  const _HostBattleChrome({
    required this.leftScore,
    required this.rightScore,
    required this.endTime,
    required this.multiplier,
    required this.winnerLiveId,
    required this.currentLiveId,
  });

  final int leftScore;
  final int rightScore;
  final DateTime? endTime;
  final double multiplier;
  final String? winnerLiveId;
  final String currentLiveId;

  @override
  Widget build(BuildContext context) {
    final winner = winnerLiveId;
    final decided = winner != null && winner.isNotEmpty;
    final leftWon = decided && winner == currentLiveId;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        PkBattleBar(scoreLeft: leftScore, scoreRight: rightScore),
        if (decided) ...[
          Positioned(
            top: 26,
            left: 8,
            child: _PkResultBadge(won: leftWon),
          ),
          Positioned(
            top: 26,
            right: 8,
            child: _PkResultBadge(won: !leftWon),
          ),
        ],
        Positioned(
          top: 22,
          child: _PkBattleTimer(endTime: endTime, multiplier: multiplier),
        ),
      ],
    );
  }
}

class _PkBattleTimer extends StatelessWidget {
  const _PkBattleTimer({required this.endTime, required this.multiplier});

  final DateTime? endTime;
  final double multiplier;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream<int>.periodic(
        const Duration(seconds: 1),
        (value) => value,
      ),
      builder: (_, _) {
        final seconds = math.max(
          0,
          endTime?.difference(DateTime.now()).inSeconds ?? 0,
        );
        final time =
            '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
            '${(seconds % 60).toString().padLeft(2, '0')}';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (multiplier > 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xE6FF2D55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '×${multiplier.toStringAsFixed(multiplier % 1 == 0 ? 0 : 1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xE614202A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PkResultBadge extends StatelessWidget {
  const _PkResultBadge({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: won ? const Color(0xE6FF2D55) : const Color(0xE6222226),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        won ? 'WIN' : 'LOSE',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// The top-three supporter ring under one side of a PK battle.
///
/// Rank 1 sits nearest the centre line on both sides, so the two leaders face
/// each other across the split — that is the arrangement TikTok uses, and it
/// survives an RTL locale because the order is expressed against the row's
/// own start/end rather than against screen left/right.
class _BattleSupporters extends StatelessWidget {
  const _BattleSupporters({required this.avatars, required this.isOwnSide});

  final List<String> avatars;

  /// This host's own side. Picks the ring colour and which end rank 1 takes.
  final bool isOwnSide;

  static const double _diameter = 30;

  @override
  Widget build(BuildContext context) {
    final ranked = avatars
        .take(3)
        .indexed
        .map((item) => (url: item.$2, rank: item.$1 + 1))
        .toList(growable: false);
    // Reserve the strip's height even when empty, so the stage does not jump
    // the moment the first gift lands.
    if (ranked.isEmpty) return const SizedBox(height: _diameter + 4);

    final ordered = isOwnSide
        ? ranked.reversed.toList(growable: false)
        : ranked;
    final ring = isOwnSide ? const Color(0xFFFF5A8A) : const Color(0xFF25F4EE);

    return Row(
      mainAxisAlignment: isOwnSide
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _SupporterAvatar(
            url: ordered[i].url,
            rank: ordered[i].rank,
            ring: ring,
            diameter: _diameter,
          ),
        ],
      ],
    );
  }
}

class _SupporterAvatar extends StatelessWidget {
  const _SupporterAvatar({
    required this.url,
    required this.rank,
    required this.ring,
    required this.diameter,
  });

  final String url;
  final int rank;
  final Color ring;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 1.6),
            ),
            child: ClipOval(
              child: SafeNetworkImage(
                imageUrl: url,
                width: diameter,
                height: diameter,
                blankOnError: true,
                showLoadingIndicator: false,
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ring,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpponentVideo extends StatefulWidget {
  const _OpponentVideo({required this.room, this.avatarUrl});

  final Room? room;
  final String? avatarUrl;

  @override
  State<_OpponentVideo> createState() => _OpponentVideoState();
}

class _OpponentVideoState extends State<_OpponentVideo> {
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _track;
  String? _trackKey;
  Timer? _trackPollTimer;

  @override
  void initState() {
    super.initState();
    debugPrint(
      '[PK-DIAG][${DateTime.now().toIso8601String()}] '
      'opponent_video_widget_create roomHash=${widget.room?.hashCode}',
    );
    _attach(widget.room);
  }

  @override
  void didUpdateWidget(covariant _OpponentVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room)) {
      debugPrint(
        '[PK-DIAG][${DateTime.now().toIso8601String()}] '
        'opponent_video_room_swap '
        'from=${oldWidget.room?.hashCode} to=${widget.room?.hashCode}',
      );
      _detach();
      _attach(widget.room);
    }
  }

  @override
  void dispose() {
    debugPrint(
      '[PK-DIAG][${DateTime.now().toIso8601String()}] '
      'opponent_video_widget_dispose trackKey=$_trackKey',
    );
    _detach();
    super.dispose();
  }

  void _detach() {
    _trackPollTimer?.cancel();
    _trackPollTimer = null;
    _listener?.dispose();
    _listener = null;
  }

  void _attach(Room? room) {
    _refreshTrack(room);
    if (room == null) return;
    final listener = room.createListener();
    _listener = listener;
    listener
      ..on<TrackSubscribedEvent>((event) {
        final track = event.track;
        if (track is RemoteVideoTrack) {
          _bindOpponentTrack(track);
        } else {
          _refreshTrack(room);
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        final sid = event.track.sid ?? event.publication.sid;
        if (sid == _trackKey || sid == _track?.sid) {
          _track = null;
          _trackKey = null;
          _refreshTrack(room);
        }
      })
      ..on<TrackMutedEvent>((_) => _refreshTrack(room))
      ..on<TrackUnmutedEvent>((_) => _refreshTrack(room))
      ..on<ParticipantConnectedEvent>((_) => _refreshTrack(room))
      ..on<ParticipantDisconnectedEvent>((_) => _refreshTrack(room));
    // Release builds can miss the first TrackSubscribedEvent; poll until the
    // opponent host video is attached or the room is replaced.
    _trackPollTimer?.cancel();
    _trackPollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !identical(widget.room, room)) {
        _trackPollTimer?.cancel();
        _trackPollTimer = null;
        return;
      }
      _refreshTrack(room);
      if (_track != null) {
        _trackPollTimer?.cancel();
        _trackPollTimer = null;
      }
    });
  }

  void _bindOpponentTrack(RemoteVideoTrack track) {
    final key = track.sid ?? '${track.hashCode}';
    if (key == _trackKey && identical(track, _track)) return;
    if (!mounted) {
      _track = track;
      _trackKey = key;
      return;
    }
    debugPrint(
      '[PK-DIAG][${DateTime.now().toIso8601String()}] '
      'opponent_renderer_track_change from=$_trackKey to=$key',
    );
    setState(() {
      _track = track;
      _trackKey = key;
    });
  }

  void _refreshTrack(Room? room) {
    VideoTrack? next;
    VideoTrack? mutedFallback;
    final participants = room?.remoteParticipants.values;
    if (participants != null) {
      for (final participant in participants) {
        for (final publication in participant.videoTrackPublications) {
          final track = publication.track;
          if (!publication.subscribed || track == null) continue;
          if (!publication.muted) {
            next = track;
          } else {
            mutedFallback ??= track;
          }
        }
      }
    }
    next ??= mutedFallback;
    final key = next == null ? null : (next.sid ?? '${next.hashCode}');
    if (!mounted) {
      _track = next;
      _trackKey = key;
      return;
    }
    if (key == _trackKey && identical(next, _track)) return;
    debugPrint(
      '[PK-DIAG][${DateTime.now().toIso8601String()}] '
      'opponent_renderer_track_change from=$_trackKey to=$key',
    );
    setState(() {
      _track = next;
      _trackKey = key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final track = _track;
    if (track != null) {
      return RepaintBoundary(
        child: VideoTrackRenderer(
          track,
          key: ValueKey('pk-opponent-$_trackKey'),
          fit: VideoViewFit.cover,
        ),
      );
    }
    if (isValidNetworkImageUrl(widget.avatarUrl)) {
      return SafeNetworkImage(
        imageUrl: widget.avatarUrl,
        fit: BoxFit.cover,
        blankOnError: true,
        showLoadingIndicator: false,
      );
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
      VideoTrack? last;
      for (final publication in participant.videoTrackPublications) {
        if (publication.subscribed && !publication.muted) {
          final track = publication.track;
          if (track != null) last = track;
        }
      }
      return last;
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
