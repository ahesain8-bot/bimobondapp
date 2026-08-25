import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/auction_audio_gift_chip_session.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_price_with_audio_badge.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/gift_animation_overlay.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/entities/gift_entity.dart';
import 'fallback_media.dart';
import 'gift_icon.dart';
import 'tiktok_live_tokens.dart';
import '../../../../core/widgets/gifter_level_badge.dart';

/// Combo gift toast (left) + center burst — TikTok LIVE timing/layout.
class FloatingGiftsLayer extends StatefulWidget {
  final List<GiftSentEntity> recentGifts;
  final GiftSentEntity? activeGift;
  final GiftComboPayload? latestCombo;
  final VoidCallback? onAnimationComplete;

  /// Reports the combo back once it has been presented, so the owning BLoC can
  /// release it. Without this the latched combo is replayed the next time this
  /// layer mounts — on whatever route happens to be on screen by then.
  final ValueChanged<GiftComboPayload>? onComboConsumed;

  const FloatingGiftsLayer({
    super.key,
    required this.recentGifts,
    this.activeGift,
    this.latestCombo,
    this.onAnimationComplete,
    this.onComboConsumed,
  });

  @override
  State<FloatingGiftsLayer> createState() => _FloatingGiftsLayerState();
}

class _FloatingGiftsLayerState extends State<FloatingGiftsLayer> {
  final Map<String, GiftComboItem> _activeCombos = {};
  final Map<String, Timer> _comboTimers = {};
  final Set<String> _playedAnimations = {};
  final _audioSession = AuctionAudioGiftChipSession();
  String? _audioLabel;
  String? _audioColor;
  GiftComboPayload? _pendingCombo;

  @override
  void initState() {
    super.initState();
    final combo = widget.latestCombo;
    if (combo != null) _scheduleCombo(combo);
  }

  @override
  void didUpdateWidget(covariant FloatingGiftsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final combo = widget.latestCombo;
    if (combo != null && combo != oldWidget.latestCombo) {
      _scheduleCombo(combo);
    }
  }

  /// Presents [payload] at the end of the current frame instead of inline.
  ///
  /// [didUpdateWidget] runs inside the build phase, and a medium/large gift is
  /// presented by inserting an entry into the *root* overlay — a `setState` on
  /// an ancestor, which Flutter cannot schedule mid-build. The entry then sat
  /// in the overlay unmounted until something else rebuilt it, which is why the
  /// broadcaster saw nothing until the room was popped.
  void _scheduleCombo(GiftComboPayload payload) {
    if (identical(_pendingCombo, payload)) return;
    _pendingCombo = payload;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_pendingCombo, payload)) return;
      _pendingCombo = null;
      _consumeCombo(payload);
    });
    // A post-frame callback only runs if a frame is actually produced.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    GiftAnimationOverlay.dismiss(owner: this);
    for (final timer in _comboTimers.values) {
      timer.cancel();
    }
    _comboTimers.clear();
    _audioSession.dispose();
    super.dispose();
  }

  void _consumeCombo(GiftComboPayload payload) {
    _presentCombo(payload);

    final notify = widget.onComboConsumed;
    if (notify == null) return;
    // Deferred so the acknowledgement never emits a new state mid-build, and
    // deliberately not gated on `mounted`: a layer that is torn down right
    // after a gift must still release the combo it already presented.
    scheduleMicrotask(() => notify(payload));
  }

  void _presentCombo(GiftComboPayload payload) {
    final gift = payload.gift ?? const <String, dynamic>{};
    final sender = payload.sender ?? const <String, dynamic>{};
    final giftName = _readString(payload.giftName) ??
        _readString(gift['name']) ??
        'Gift';
    final senderName = _readString(payload.senderName) ??
        _readString(sender['fullName']) ??
        _readString(sender['username']) ??
        'User';
    final senderAvatar = _readString(payload.senderAvatarUrl) ??
        _readString(sender['avatarUrl']) ??
        _readString(sender['avatar']);
    final animationUrl = _readString(
      gift['animationUrl'] ?? gift['animation_url'] ?? gift['imageUrl'],
    );
    final thumbnailUrl = _readString(
      gift['thumbnailUrl'] ?? gift['thumbnail_url'] ?? gift['imageUrl'],
    );
    final audioUrl = _readString(gift['audioUrl']);
    final type = _readString(gift['type'])?.toUpperCase();
    final isAudio = type == 'AUDIO';
    final color = _readString(gift['color']);

    if (isAudio) {
      unawaited(
        _audioSession.play(
          onUpdate: _onAudioUpdate,
          label: giftName,
          colorHex: color,
          audioUrl: audioUrl,
        ),
      );
      return;
    }

    final mediaUrl = animationUrl ?? thumbnailUrl ?? '';
    final size = _readString(gift['size'] ?? gift['giftSize']);
    final normalizedSize = size?.toUpperCase();

    // A payload the catalog could not hydrate still has a sender, a gift name
    // and a combo count, so announce it as a combo badge. Dropping it here is
    // what left the host with nothing but the chat line.
    final isSmall = mediaUrl.isEmpty ||
        normalizedSize == 'SMALL' ||
        (normalizedSize == null && animationUrl == null);
    final comboKey = payload.overlayKey.isNotEmpty
        ? payload.overlayKey
        : '${payload.senderId}_${payload.giftId}';
    final combo = payload.combo > 0 ? payload.combo : 1;

    if (isSmall) {
      final current = _activeCombos[comboKey];
      if (current == null) {
        setState(() {
          _activeCombos[comboKey] = GiftComboItem(
            senderId: payload.senderId,
            senderName: senderName,
            senderAvatarUrl: senderAvatar,
            giftId: payload.giftId,
            giftName: giftName,
            animationUrl: mediaUrl,
            thumbnailUrl: thumbnailUrl,
            combo: combo,
          );
        });
      } else if (combo > current.combo) {
        setState(() => current.combo = combo);
      }
      _restartComboTimer(comboKey);
      return;
    }

    final shouldPlay = _playedAnimations.add(comboKey);
    _restartComboTimer(comboKey);
    if (shouldPlay && mounted) {
      unawaited(
        GiftAnimationOverlay.show(
          context,
          animationUrl: mediaUrl,
          thumbnailUrl: thumbnailUrl,
          senderName: senderName,
          giftName: giftName,
          size: size,
          owner: this,
        ),
      );
    }
  }

  void _restartComboTimer(String key) {
    _comboTimers[key]?.cancel();
    _comboTimers[key] = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _activeCombos.remove(key));
      _playedAnimations.remove(key);
      _comboTimers.remove(key);
    });
  }

  void _onAudioUpdate(String? label, String? colorHex) {
    if (!mounted) return;
    setState(() {
      _audioLabel = label;
      _audioColor = colorHex;
    });
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Color _audioAccent() {
    final raw = _audioColor?.replaceFirst('#', '');
    if (raw == null || (raw.length != 6 && raw.length != 8)) {
      return Colors.white;
    }
    try {
      final value = int.parse(raw, radix: 16);
      return Color(raw.length == 6 ? 0xFF000000 | value : value);
    } catch (_) {
      return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final top =
        MediaQuery.paddingOf(context).top + TikTokLiveTokens.toastTopFromSafe;
    final activeCombos = _activeCombos.values.toList();

    return Stack(
      children: [
        Positioned(
          left: TikTokLiveTokens.toastLeft,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: activeCombos.isNotEmpty
                ? activeCombos.take(2).map((combo) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: SmallGiftHighestPriceBadge(
                        key: ValueKey(combo.key),
                        animationUrl: combo.animationUrl,
                        thumbnailUrl: combo.thumbnailUrl,
                        giftName: combo.giftName,
                        senderName: combo.senderName,
                        senderAvatarUrl: combo.senderAvatarUrl,
                        quantity: combo.combo,
                      ),
                    );
                  }).toList()
                : widget.recentGifts.take(2).map((g) {
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
        if (_audioLabel != null)
          Positioned(
            left: TikTokLiveTokens.toastLeft,
            top: top + 58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _audioAccent().withValues(alpha: 0.7)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  _audioLabel!,
                  style: TextStyle(
                    color: _audioAccent(),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        if (widget.activeGift != null)
          Positioned.fill(
            child: _GiftBurst(
              gift: widget.activeGift!,
              onComplete: widget.onAnimationComplete,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
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
                        ),
                        if ((gift.senderGifterLevel ?? 0) > 0) ...[
                          const SizedBox(width: 4),
                          GifterLevelBadge(
                            level: gift.senderGifterLevel!,
                            compact: true,
                          ),
                        ],
                      ],
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

  const CoinBalanceChip({super.key, required this.balance, this.delta = 0});

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
              const Icon(
                Icons.monetization_on,
                color: AppColors.coinGold,
                size: 16,
              ),
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
            child:
                Text(
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
