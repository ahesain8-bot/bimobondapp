import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/live_entity.dart';
import 'fallback_media.dart';
import 'guest_panel.dart';
import 'live_video_player.dart';

/// Multi-guest grid — proportions matched to TikTok LIVE reference.
/// Top: 2 large tiles. Bottom: 2×4 small tiles. One Request slot when full.
class MultiGuestGrid extends StatelessWidget {
  final LiveEntity live;
  final bool isActive;
  final List<GuestSlotData> guests;
  final VoidCallback onRequestTap;
  final double topInset;
  final double bottomInset;

  static const double gap = 4.0;
  static const double hPad = 4.0;
  static const double tileR = 8.0;

  /// Fixed compact grid height for a given screen width (matches tile math).
  static double gridHeightForWidth(double screenWidth) {
    final gridW = screenWidth - hPad * 2;
    final smallSide = (gridW - gap * 3) / 4;
    final largeH = smallSide * 2 + gap;
    return largeH + gap + smallSide + gap + smallSide;
  }

  const MultiGuestGrid({
    super.key,
    required this.live,
    required this.isActive,
    required this.guests,
    required this.onRequestTap,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final filled = guests.where((g) => !g.isEmpty).toList();
    // Ensure up to 7 filled guests so only the last small slot is Request.
    final ensured = <GuestSlotData>[
      ...filled,
      for (var i = filled.length; i < 7; i++)
        GuestSlotData(
          userId: 'pad_${live.id}_$i',
          name: 'Guest ${i + 1}',
          avatarUrl: 'https://i.pravatar.cc/150?u=${live.id}_g$i',
          level: 10 + i * 7,
          isMuted: i.isOdd,
        ),
    ];
    final topGuest = ensured.first;
    final rest = ensured.skip(1).take(7).toList();

    final gridW = MediaQuery.sizeOf(context).width - hPad * 2;
    final smallSide = (gridW - gap * 3) / 4;
    final largeH = smallSide * 2 + gap;
    final gridH = largeH + gap + smallSide + gap + smallSide;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, topInset, hPad, bottomInset),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: gridW,
          height: gridH,
          child: Column(
            children: [
              SizedBox(
                height: largeH,
                child: Row(
                  children: [
                    Expanded(
                      child: _HostTile(live: live, isActive: isActive),
                    ),
                    const SizedBox(width: gap),
                    Expanded(child: _GuestTile(guest: topGuest, large: true)),
                  ],
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: smallSide,
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                        child: i < rest.length
                            ? _GuestTile(guest: rest[i])
                            : _RequestTile(onTap: onRequestTap),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: gap),
              SizedBox(
                height: smallSide,
                child: Row(
                  children: [
                    for (var i = 4; i < 8; i++) ...[
                      if (i > 4) const SizedBox(width: gap),
                      Expanded(
                        child: i < rest.length
                            ? _GuestTile(guest: rest[i])
                            : _RequestTile(onTap: onRequestTap),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostTile extends StatelessWidget {
  final LiveEntity live;
  final bool isActive;

  const _HostTile({required this.live, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MultiGuestGrid.tileR),
      child: Stack(
        fit: StackFit.expand,
        children: [
          LiveVideoPlayer(live: live, isActive: isActive, liveKitOnly: true),
          // Host badge — top-right (LTR)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A00),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 10, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'Host',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Name pill — bottom center
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  live.hostName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
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

class _GuestTile extends StatelessWidget {
  final GuestSlotData guest;
  final bool large;

  const _GuestTile({required this.guest, this.large = false});

  @override
  Widget build(BuildContext context) {
    final avatar = large ? 52.0 : 34.0;
    final name = guest.name ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(MultiGuestGrid.tileR),
      child: ColoredBox(
        color: const Color(0xFF1A1A1C),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF26262A), Color(0xFF121214)],
                ),
              ),
            ),
            Center(
              child: ClipOval(
                child: SizedBox(
                  width: avatar,
                  height: avatar,
                  child: CachedNetworkImage(
                    imageUrl: guest.avatarUrl ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => FallbackAvatar(
                      seed: guest.userId ?? 'g',
                      name: name.isEmpty ? 'G' : name,
                      radius: avatar / 2,
                    ),
                  ),
                ),
              ),
            ),
            // Points / diamond — top-right
            if (guest.level != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond,
                        size: 9,
                        color: Color(0xFF7EC8FF),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${guest.level}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Bottom pill: name · mic · +  (LTR)
            Positioned(
              left: 4,
              right: 4,
              bottom: 4,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: large ? 140 : 86),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: large ? 11 : 9.5,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                      if (guest.isMuted) ...[
                        const SizedBox(width: 3),
                        Icon(
                          Icons.mic_off,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: large ? 12 : 10,
                        ),
                      ],
                      const SizedBox(width: 3),
                      Icon(
                        Icons.add,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: large ? 13 : 11,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final VoidCallback onTap;

  const _RequestTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MultiGuestGrid.tileR),
        child: ColoredBox(
          color: const Color(0xFF1C1C1E),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: Colors.white.withValues(alpha: 0.55),
                size: 26,
              ),
              const SizedBox(height: 2),
              Text(
                'Request',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
