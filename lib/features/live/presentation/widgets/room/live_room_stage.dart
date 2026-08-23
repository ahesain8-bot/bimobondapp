import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../../core/utils/build_safe_notifier.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';
import 'live_room_camera_layer.dart';

/// Width ÷ height of the shared video box when more than one person is on
/// stage, matched to the TikTok reference: the two feeds sit side by side in a
/// landscape-ish box under the header rather than filling the screen.
const double kStageAspect = 1.35;

/// Gap and corner radius between stage tiles.
const double _tileGap = 2;
const double _tileRadius = 6;

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

        final width = MediaQuery.sizeOf(context).width;
        final room = context.read<LiveSessionRepository>().mediaRoom;

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              width: width,
              height: width / kStageAspect,
              child: LiveRoomStageTiles(
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

/// Host first, then every guest, all the same size.
///
/// Two people split the box down the middle, which is the case the reference
/// shows. Three or four wrap into a 2×2 so nobody is ever the odd one out in a
/// row of unequal tiles.
class LiveRoomStageTiles extends StatelessWidget {
  const LiveRoomStageTiles({super.key, required this.tiles});

  /// Host first, then one per guest.
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    // Local override only: the host holds the first tile on the LEFT, the way
    // the reference lays it out. Left to itself the Row mirrors in Arabic and
    // the two feeds swap sides.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: tiles.length <= 3
          ? _TileRow(tiles: tiles)
          : Column(
              children: [
                Expanded(child: _TileRow(tiles: _topRow)),
                const SizedBox(height: _tileGap),
                Expanded(child: _TileRow(tiles: _bottomRow)),
              ],
            ),
    );
  }

  /// Splits 4+ tiles so the wider row comes first — a 5-up reads as 3 over 2,
  /// never as 2 over 3 with a stretched pair underneath.
  List<Widget> get _topRow => tiles.take((tiles.length / 2).ceil()).toList();

  List<Widget> get _bottomRow => tiles.skip((tiles.length / 2).ceil()).toList();
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: _tileGap),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_tileRadius),
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
