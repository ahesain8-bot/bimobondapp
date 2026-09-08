import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../data/datasources/live_secondary_rooms.dart';
import '../../../domain/entities/live_cohost.dart';

/// Renders the co-host partner rooms as their own tiles
/// (`lives/live-p1-parity.md` §6, `live-p2-parity.md` §2).
///
/// Each tile is backed by a separate LiveKit room held in [rooms] and keyed by
/// its live id, so one partner reconnecting or leaving never disturbs another
/// tile or the primary room.
class LiveCohostTiles extends StatelessWidget {
  const LiveCohostTiles({
    super.key,
    required this.rooms,
    required this.partners,
    this.height = 120,
  });

  final LiveSecondaryRooms rooms;

  /// Partner rooms as the join/start payload listed them, in order.
  final List<LiveCohostRoom> partners;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: rooms,
      builder: (context, _) {
        return SizedBox(
          height: height,
          child: Row(
            children: [
              for (final partner in partners)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _CohostTile(
                      partner: partner,
                      track: rooms.videoTrackFor(
                        partner.liveId,
                        hostIdentity: partner.hostIdentity,
                        hostId: partner.hostId,
                      ),
                      connecting: rooms.isConnecting(partner.liveId),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CohostTile extends StatelessWidget {
  const _CohostTile({
    required this.partner,
    required this.track,
    required this.connecting,
  });

  final LiveCohostRoom partner;
  final RemoteVideoTrack? track;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final video = track;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Colors.black54,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              VideoTrackRenderer(video, fit: VideoViewFit.cover)
            else
              Center(
                child: connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.videocam_off_outlined,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
              ),
            if (partner.hostName != null && partner.hostName!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Text(
                    partner.hostName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
