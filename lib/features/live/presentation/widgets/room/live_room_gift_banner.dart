import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/widgets/gifter_level_badge.dart';
import '../../../domain/entities/live_gift_banner.dart';
import '../../bloc/live_room/live_room_bloc.dart';
import '../../bloc/live_room/live_room_event.dart';
import '../../bloc/live_room/live_room_state.dart';

/// Gift celebration over the video: slides in from the start edge, holds, then
/// slides back out, the way TikTok announces a gift above the comment run.
class LiveRoomGiftBanner extends StatefulWidget {
  const LiveRoomGiftBanner({super.key});

  static const Duration _visibleFor = Duration(milliseconds: 2600);

  @override
  State<LiveRoomGiftBanner> createState() => _LiveRoomGiftBannerState();
}

class _LiveRoomGiftBannerState extends State<LiveRoomGiftBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  Timer? _holdTimer;
  String? _playingId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _slide = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _play(LiveGiftBanner banner) {
    if (_playingId == banner.id) return;
    _playingId = banner.id;
    _holdTimer?.cancel();
    _controller.forward(from: 0);
    _holdTimer = Timer(LiveRoomGiftBanner._visibleFor, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (!mounted) return;
      _playingId = null;
      context.read<LiveRoomBloc>().add(const LiveRoomGiftBannerConsumed());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveRoomBloc, LiveRoomState>(
      buildWhen: (previous, current) =>
          current is LiveRoomReady &&
          (previous is! LiveRoomReady ||
              previous.giftBanner?.id != current.giftBanner?.id),
      builder: (context, state) {
        final banner = state is LiveRoomReady ? state.giftBanner : null;
        if (banner == null) return const SizedBox.shrink();

        // Scheduled rather than called inline: this runs during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _play(banner);
        });

        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: _BannerCard(banner: banner),
          ),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final LiveGiftBanner banner;

  @override
  Widget build(BuildContext context) {
    final avatar = banner.senderAvatarUrl;
    final image = banner.giftImageUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xE6C2185B), Color(0x33C2185B)],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white70, width: 1.5),
              image: avatar != null && avatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatar),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: avatar != null && avatar.isNotEmpty
                ? null
                : const Icon(Icons.person, size: 19, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((banner.gifterLevel ?? 0) > 0) ...[
                    GifterLevelBadge(level: banner.gifterLevel!, compact: true),
                    const SizedBox(width: 4),
                  ],
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      banner.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                banner.giftName == null || banner.giftName!.isEmpty
                    ? 'أرسل هدية'
                    : 'أرسل ${banner.giftName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          if (image != null && image.isNotEmpty)
            Image.network(
              image,
              width: 34,
              height: 34,
              errorBuilder: (_, _, _) => _GiftGlyph(icon: banner.giftIcon),
            )
          else
            _GiftGlyph(icon: banner.giftIcon),
          if (banner.showsMultiplier) ...[
            const SizedBox(width: 6),
            Text(
              'x${banner.quantity}',
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 18,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Falls back to the emoji the catalog ships when there is no artwork URL.
class _GiftGlyph extends StatelessWidget {
  const _GiftGlyph({this.icon});

  final String? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null && icon!.isNotEmpty) {
      return Text(icon!, style: const TextStyle(fontSize: 26));
    }
    return const Icon(Icons.card_giftcard, size: 26, color: Colors.white);
  }
}
