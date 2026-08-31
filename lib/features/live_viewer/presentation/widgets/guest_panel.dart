import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'fallback_media.dart';
import 'tiktok_live_tokens.dart';

class GuestSlotData {
  final String? userId;
  final String? name;
  final String? avatarUrl;
  final int? level;
  final bool isHost;
  final bool isMuted;

  const GuestSlotData({
    this.userId,
    this.name,
    this.avatarUrl,
    this.level,
    this.isHost = false,
    this.isMuted = false,
  });

  bool get isEmpty => userId == null;
}

/// Vertical co-host request panel — matched to TikTok LIVE sidebar.
class GuestRequestPanel extends StatelessWidget {
  final List<GuestSlotData> slots;
  final VoidCallback onRequestTap;
  final int maxSlots;

  const GuestRequestPanel({
    super.key,
    required this.slots,
    required this.onRequestTap,
    this.maxSlots = 8,
  });

  static const double _tile = 58;
  static const double _gap = 3;
  static const double _radius = 10;

  @override
  Widget build(BuildContext context) {
    final items = List<GuestSlotData>.generate(
      maxSlots,
      (i) => i < slots.length ? slots[i] : const GuestSlotData(),
    );

    return SizedBox(
      width: _tile + 4,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            _GuestSlotTile(
              slot: items[i],
              size: _tile,
              radius: _radius,
              onRequestTap: onRequestTap,
              showHostTag: i == 0 && items[i].isHost,
            ),
          ],
        ],
      ),
    );
  }
}

class _GuestSlotTile extends StatelessWidget {
  final GuestSlotData slot;
  final double size;
  final double radius;
  final VoidCallback onRequestTap;
  final bool showHostTag;

  const _GuestSlotTile({
    required this.slot,
    required this.size,
    required this.radius,
    required this.onRequestTap,
    this.showHostTag = false,
  });

  @override
  Widget build(BuildContext context) {
    if (slot.isEmpty) {
      return GestureDetector(
        onTap: onRequestTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                color: Colors.white.withValues(alpha: 0.45),
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                'Request',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF1C1C1E)),
            Center(
              child: ClipOval(
                child: SizedBox(
                  width: size * 0.62,
                  height: size * 0.62,
                  child: CachedNetworkImage(
                    imageUrl: slot.avatarUrl ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => FallbackAvatar(
                      seed: slot.userId ?? 'g',
                      name: slot.name,
                      radius: size * 0.31,
                    ),
                  ),
                ),
              ),
            ),
            if (slot.level != null)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6BFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${slot.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (showHostTag)
              Positioned(
                top: 3,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: TikTokLiveTokens.hostTagOrange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Host',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (slot.isMuted)
              Positioned(
                left: 3,
                bottom: 16,
                child: Icon(
                  Icons.mic_off,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 11,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.black.withValues(alpha: 0.50),
                child: Text(
                  slot.name ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
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

/// Guest request bottom sheet — white TikTok LIVE style (reference).
Future<bool?> showGuestRequestSheet(
  BuildContext context, {
  required String hostName,
  String? hostAvatar,
  String? viewerAvatar,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _SheetIconBtn(icon: Icons.settings_outlined, onTap: () {}),
                const SizedBox(width: 8),
                _SheetIconBtn(icon: Icons.auto_awesome_outlined, onTap: () {}),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              width: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 8,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8E8E8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipOval(
                        child: viewerAvatar != null
                            ? CachedNetworkImage(
                                imageUrl: viewerAvatar,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.black38,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 32,
                                color: Colors.black38,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: hostAvatar ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => FallbackAvatar(
                            seed: hostName,
                            name: hostName,
                            radius: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Request to join as a guest',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '1 viewer is sending a request',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.45),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Join the LIVE with @$hostName. Guests who go live may receive rewards from the host.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.50),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: TikTokLiveTokens.liveRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  Expanded(
                    child: Text(
                      'Find more available spots',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25F4EE).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 160.ms).slideY(begin: 0.06, end: 0);
    },
  );
}

class _SheetIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SheetIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0xFFF0F0F0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.black54),
      ),
    );
  }
}
