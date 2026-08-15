import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/gift_entity.dart';
import 'fallback_media.dart';
import 'gift_icon.dart';
import 'tiktok_live_tokens.dart';

/// Combo gift toast (left) + center burst — TikTok LIVE timing/layout.
class FloatingGiftsLayer extends StatelessWidget {
  final List<GiftSentEntity> recentGifts;
  final GiftSentEntity? activeGift;
  final VoidCallback? onAnimationComplete;

  const FloatingGiftsLayer({
    super.key,
    required this.recentGifts,
    this.activeGift,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    final top =
        MediaQuery.paddingOf(context).top + TikTokLiveTokens.toastTopFromSafe;

    return Stack(
      children: [
        Positioned(
          left: TikTokLiveTokens.toastLeft,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: recentGifts.take(2).map((g) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _GiftToast(gift: g)
                    .animate(key: ValueKey(g.id))
                    .slideX(
                      begin: -0.5,
                      end: 0,
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 180.ms),
              );
            }).toList(),
          ),
        ),
        if (activeGift != null)
          Positioned.fill(
            child: _GiftBurst(
              gift: activeGift!,
              onComplete: onAnimationComplete,
            ),
          ),
      ],
    );
  }
}

class _GiftToast extends StatelessWidget {
  final GiftSentEntity gift;

  const _GiftToast({required this.gift});

  @override
  Widget build(BuildContext context) {
    final details = gift.giftDetails;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: TikTokLiveTokens.toastH,
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(
            color: TikTokLiveTokens.frost(0.55),
            borderRadius: BorderRadius.circular(TikTokLiveTokens.toastR),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: SizedBox(
                  width: TikTokLiveTokens.toastAvatar,
                  height: TikTokLiveTokens.toastAvatar,
                  child: CachedNetworkImage(
                    imageUrl: gift.senderAvatar ?? '',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => FallbackAvatar(
                      seed: gift.senderId,
                      name: gift.senderName,
                      radius: TikTokLiveTokens.toastAvatar / 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'sent ${details?.name ?? 'Gift'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (details != null)
                GiftIcon(gift: details, size: TikTokLiveTokens.toastGiftIcon),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'x${gift.quantity}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: TikTokLiveTokens.comboFont,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 2,
                offset: Offset(1, 1),
              ),
            ],
          ),
        )
            .animate(onPlay: (c) => c.forward())
            .scale(
              begin: const Offset(0.55, 0.55),
              end: const Offset(1, 1),
              duration: 200.ms,
              curve: Curves.easeOutBack,
            ),
      ],
    );
  }
}

class _GiftBurst extends StatefulWidget {
  final GiftSentEntity gift;
  final VoidCallback? onComplete;

  const _GiftBurst({required this.gift, this.onComplete});

  @override
  State<_GiftBurst> createState() => _GiftBurstState();
}

class _GiftBurstState extends State<_GiftBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final random = Random(widget.gift.id.hashCode);
    _particles = List.generate(12, (i) {
      final angle = (i / 12) * pi * 2;
      return _Particle(
        dx: cos(angle) * (70 + random.nextDouble() * 80),
        dy: sin(angle) * (50 + random.nextDouble() * 70),
        size: 8 + random.nextDouble() * 12,
      );
    });

    final durationMs = widget.gift.giftDetails?.durationMs ?? 1600;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..forward().whenComplete(() => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gift = widget.gift.giftDetails;
    if (gift == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
        final scale = t < 0.2
            ? (t / 0.2) * 1.2
            : t < 0.45
                ? 1.2 - ((t - 0.2) / 0.25) * 0.12
                : 1.08;

        return IgnorePointer(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ..._particles.map((p) {
                return Transform.translate(
                  offset: Offset(p.dx * t, p.dy * t - 30 * t),
                  child: Opacity(
                    opacity: fade * 0.75,
                    child: Icon(
                      Icons.circle,
                      size: p.size * (1 - t * 0.4),
                      color: gift.rarity.color.withValues(alpha: 0.65),
                    ),
                  ),
                );
              }),
              Opacity(
                opacity: fade,
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GiftIcon(gift: gift, size: 88),
                      if (widget.gift.quantity > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          'x${widget.gift.quantity}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(blurRadius: 6, color: Colors.black54),
                            ],
                          ),
                        ),
                      ],
                    ],
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

class _Particle {
  final double dx;
  final double dy;
  final double size;

  _Particle({required this.dx, required this.dy, required this.size});
}

class CoinBalanceChip extends StatelessWidget {
  final int balance;
  final int delta;

  const CoinBalanceChip({
    super.key,
    required this.balance,
    this.delta = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: TikTokLiveTokens.frost(0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.coinGold.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on,
                  color: AppColors.coinGold, size: 16),
              const SizedBox(width: 4),
              Text(
                balance.formatCompactLike,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.coinGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (delta < 0)
          Positioned(
            right: -4,
            top: -14,
            child: Text(
              '$delta',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            )
                .animate()
                .fadeIn()
                .slideY(begin: 0.4, end: -0.6)
                .fadeOut(delay: 500.ms),
          ),
      ],
    );
  }
}

extension on int {
  String get formatCompactLike {
    if (this >= 1000000) return '${(this / 1000000).toStringAsFixed(1)}M';
    if (this >= 1000) return '${(this / 1000).toStringAsFixed(1)}K';
    return toString();
  }
}
