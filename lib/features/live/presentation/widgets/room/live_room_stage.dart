import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/utils/build_safe_notifier.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/repositories/live_session_repository.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_state.dart';

/// Strip of everyone else on stage, drawn above the chat feed.
///
/// The roster comes from the API (`GET /lives/:id/guests`, refreshed on every
/// `liveGuestUpdate`); the picture comes from LiveKit. Those two arrive
/// independently, so a guest the server already lists shows an avatar tile
/// until their track lands, rather than the row popping in late.
class LiveRoomStage extends StatelessWidget {
  const LiveRoomStage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is LiveRoomReady &&
          (previous is! LiveRoomReady || previous.guests != current.guests),
      builder: (context, state) {
        if (state is! LiveRoomReady) return const SizedBox.shrink();
        final guests = state.activeGuests;
        if (guests.isEmpty) return const SizedBox.shrink();

        final room = context.read<LiveSessionRepository>().mediaRoom;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.roomHorizontal,
          ),
          child: SizedBox(
            height: _tileHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: guests.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) => _GuestTile(
                guest: guests[index],
                room: room is Room ? room : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

const double _tileWidth = 96;
const double _tileHeight = 128;

class _GuestTile extends StatelessWidget {
  const _GuestTile({required this.guest, required this.room});

  final LiveGuest guest;
  final Room? room;

  @override
  Widget build(BuildContext context) {
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _tileWidth,
        height: _tileHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GuestVideo(guest: guest, room: room),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _GuestNamePlate(guest: guest),
            ),
          ],
        ),
      ),
    );

    if (room == null) return tile;
    // The Room is a ChangeNotifier: a guest publishing, unpublishing or
    // toggling their camera repaints the tile without any polling. Those
    // notifications come off WebRTC/signalling callbacks with no regard for
    // what the framework is doing, so the rebuild has to be build-safe.
    return BuildSafeListenableBuilder(
      listenable: room!,
      builder: (_, _) => tile,
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

  @override
  Widget build(BuildContext context) {
    final track = guest.cameraOffByHost ? null : _track;
    if (track != null) {
      return VideoTrackRenderer(track, fit: VideoViewFit.cover);
    }
    return _GuestPlaceholder(guest: guest);
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
    return Container(
      color: const Color(0xFF1A1A1C),
      alignment: Alignment.center,
      child: avatar != null && avatar.isNotEmpty
          ? Image.network(
              avatar,
              fit: BoxFit.cover,
              width: _tileWidth,
              height: _tileHeight,
              errorBuilder: (_, _, _) => const _GuestGlyph(),
            )
          : const _GuestGlyph(),
    );
  }
}

class _GuestGlyph extends StatelessWidget {
  const _GuestGlyph();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person, size: 30, color: Colors.white38);
  }
}

class _GuestNamePlate extends StatelessWidget {
  const _GuestNamePlate({required this.guest});

  final LiveGuest guest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            const Icon(Icons.mic_off, size: 11, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: Text(
              guest.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (guest.role.toUpperCase() == 'CO_HOST') ...[
            const SizedBox(width: 3),
            const Icon(Icons.star, size: 11, color: Color(0xFFFFC107)),
          ],
        ],
      ),
    );
  }
}
