import 'package:bimobondapp/app/gifts/presentation/utils/gift_lottie_cache.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/auction_audio_gift_shelf_chip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/compact_highest_bid.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// TikTok Gift Combo Model representing an active combo window.
class GiftComboItem {
  GiftComboItem({
    required this.senderId,
    required this.senderName,
    required this.giftId,
    required this.giftName,
    required this.animationUrl,
    this.senderAvatarUrl,
    this.thumbnailUrl,
    this.combo = 1,
  });

  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String giftId;
  final String giftName;
  final String animationUrl;
  final String? thumbnailUrl;
  int combo;

  String get key => '${senderId}_$giftId';
}

/// Stacks an optional audio-gift shelf chip or small gift animation directly above the auction bid card.
class AuctionPriceWithAudioBadge extends StatelessWidget {
  const AuctionPriceWithAudioBadge({
    required this.topBidLabel,
    required this.bidAmountText,
    required this.popAnimation,
    required this.theme,
    this.activeCombos = const [],
    this.audioGiftLabel,
    this.audioGiftColor,
    this.smallGiftAnimationUrl,
    this.smallGiftThumbnailUrl,
    this.smallGiftName,
    this.smallGiftSenderName,
    this.smallGiftSenderAvatarUrl,
    this.smallGiftQuantity = 1,
    this.targetPrice,
    this.targetPriceLabel,
    this.targetPriceHeader,
    this.isFinished = false,
    this.showGiftIcon = false,
    this.showCoinIcon = false,
    this.bidAmountCoins,
    this.margin = LiveDetailsLayoutConstants.screenHorizontalPadding,
    super.key,
  });

  final List<GiftComboItem> activeCombos;
  final String? audioGiftLabel;
  final String? audioGiftColor;
  final String? smallGiftAnimationUrl;
  final String? smallGiftThumbnailUrl;
  final String? smallGiftName;
  final String? smallGiftSenderName;
  final String? smallGiftSenderAvatarUrl;
  final int smallGiftQuantity;
  final String topBidLabel;
  final String bidAmountText;
  final int? targetPrice;
  final String? targetPriceLabel;
  final String? targetPriceHeader;
  final bool isFinished;
  final bool showGiftIcon;
  final bool showCoinIcon;
  final int? bidAmountCoins;
  final Animation<double> popAnimation;
  final ThemeData theme;
  final EdgeInsetsGeometry margin;

  bool get _showAudioChip {
    final label = audioGiftLabel?.trim();
    return label != null && label.isNotEmpty;
  }

  bool get _showSmallGift {
    final url = smallGiftAnimationUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    Widget? topWidget;
    if (activeCombos.isNotEmpty) {
      topWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: activeCombos.take(3).map((item) {
          return Padding(
            key: ValueKey<String>('combo-${item.key}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: SmallGiftHighestPriceBadge(
              animationUrl: item.animationUrl,
              thumbnailUrl: item.thumbnailUrl,
              giftName: item.giftName,
              senderName: item.senderName,
              senderAvatarUrl: item.senderAvatarUrl,
              quantity: item.combo,
            ),
          );
        }).toList(),
      );
    } else if (_showSmallGift) {
      topWidget = Padding(
        key: ValueKey<String>('small-gift-${smallGiftAnimationUrl!.trim()}'),
        padding: const EdgeInsets.only(bottom: 8),
        child: SmallGiftHighestPriceBadge(
          animationUrl: smallGiftAnimationUrl!,
          thumbnailUrl: smallGiftThumbnailUrl,
          giftName: smallGiftName,
          senderName: smallGiftSenderName,
          senderAvatarUrl: smallGiftSenderAvatarUrl,
          quantity: smallGiftQuantity,
        ),
      );
    } else if (_showAudioChip) {
      topWidget = Padding(
        key: ValueKey<String>(audioGiftLabel!.trim()),
        padding: const EdgeInsets.only(bottom: 8),
        child: AuctionAudioGiftShelfChip(
          label: audioGiftLabel!.trim(),
          colorHex: audioGiftColor,
          isPlaying: true,
        ),
      );
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: topWidget ??
                const SizedBox.shrink(key: ValueKey<String>('no-top-badge')),
          ),
          CompactHighestBid(
            topBidLabel: topBidLabel,
            bidAmountText: bidAmountText,
            bidAmountCoins: bidAmountCoins,
            targetPrice: targetPrice,
            targetPriceLabel: targetPriceLabel,
            targetPriceHeader: targetPriceHeader,
            isFinished: isFinished,
            showGiftIcon: showGiftIcon,
            showCoinIcon: showCoinIcon,
            popAnimation: popAnimation,
            theme: theme,
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// TikTok-style small gift streak card (Avatar + Sender + "sent Gift" + Gift Icon + "x1").
class SmallGiftHighestPriceBadge extends StatefulWidget {
  const SmallGiftHighestPriceBadge({
    required this.animationUrl,
    this.thumbnailUrl,
    this.giftName,
    this.senderName,
    this.senderAvatarUrl,
    this.quantity = 1,
    super.key,
  });

  final String animationUrl;
  final String? thumbnailUrl;
  final String? giftName;
  final String? senderName;
  final String? senderAvatarUrl;
  final int quantity;

  @override
  State<SmallGiftHighestPriceBadge> createState() =>
      _SmallGiftHighestPriceBadgeState();
}

class _SmallGiftHighestPriceBadgeState
    extends State<SmallGiftHighestPriceBadge>
    with TickerProviderStateMixin {
  LottieComposition? _composition;
  bool _lottieFailed = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _enterController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.4)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_bounceController);

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0, 0.65, curve: Curves.easeOut),
    );
    _enterController.forward();

    _loadLottie();
  }

  void _loadLottie() {
    final resolved = MediaUtils.resolveAbsoluteUrl(widget.animationUrl);
    if (GiftLottieCache.looksLikeLottieUrl(resolved)) {
      GiftLottieCache.instance.load(resolved).then((comp) {
        if (mounted) {
          if (comp == null) {
            setState(() => _lottieFailed = true);
          } else {
            setState(() => _composition = comp);
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SmallGiftHighestPriceBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationUrl != widget.animationUrl) {
      _loadLottie();
    }
    if (oldWidget.quantity != widget.quantity) {
      _bounceController.forward(from: 0).then((_) {
        if (mounted) _bounceController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUtils.resolveAbsoluteUrl(widget.animationUrl);
    final comp = _composition;
    final giftLabel = (widget.giftName ?? 'Gift').trim();
    final senderLabel = (widget.senderName ?? 'User').trim();
    final avatarUrl = widget.senderAvatarUrl?.trim();

    Widget media;
    if (comp != null) {
      media = Lottie(
        composition: comp,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      );
    } else if (!_lottieFailed && GiftLottieCache.looksLikeLottieUrl(resolved)) {
      media = const SizedBox.shrink();
    } else {
      final thumb = widget.thumbnailUrl ?? resolved;
      media = SafeNetworkImage(
        imageUrl: thumb,
        width: 44,
        height: 44,
        fit: BoxFit.contain,
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // TikTok Style Gift Capsule Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: avatarUrl != null && avatarUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SafeNetworkImage(
                              imageUrl:
                                  MediaUtils.resolveAbsoluteUrl(avatarUrl),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            senderLabel.isNotEmpty
                                ? senderLabel[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'sent $giftLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: media,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // TikTok Style Large Multiplier with Bounce Animation
            ScaleTransition(
              scale: _bounceAnimation,
              child: Text(
                'x${widget.quantity > 0 ? widget.quantity : 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: Colors.black87,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
