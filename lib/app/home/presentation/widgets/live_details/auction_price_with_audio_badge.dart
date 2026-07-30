import 'package:bimobondapp/app/gifts/presentation/widgets/auction_audio_gift_shelf_chip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/compact_highest_bid.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:flutter/material.dart';

/// Stacks an optional audio-gift shelf chip above the auction bid card.
class AuctionPriceWithAudioBadge extends StatelessWidget {
  const AuctionPriceWithAudioBadge({
    required this.topBidLabel,
    required this.bidAmountText,
    required this.popAnimation,
    required this.theme,
    this.audioGiftLabel,
    this.audioGiftColor,
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

  final String? audioGiftLabel;
  final String? audioGiftColor;
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

  @override
  Widget build(BuildContext context) {
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
            child: _showAudioChip
                ? Padding(
                    key: ValueKey<String>(audioGiftLabel!.trim()),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AuctionAudioGiftShelfChip(
                      label: audioGiftLabel!.trim(),
                      colorHex: audioGiftColor,
                      isPlaying: true,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey<String>('no-audio-chip')),
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
