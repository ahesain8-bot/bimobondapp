import 'dart:ui';

import 'package:bimobondapp/app/gifts/domain/entities/gift_entity.dart';
import 'package:bimobondapp/app/gifts/presentation/utils/gift_accent_color.dart';
import 'package:bimobondapp/app/gifts/presentation/widgets/gift_vinyl_record_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style now-playing pill above the auction bid card ([AUDIO] gifts).
class AuctionAudioGiftShelfChip extends StatelessWidget {
  const AuctionAudioGiftShelfChip({
    required this.label,
    this.colorHex,
    this.isPlaying = true,
    super.key,
  });

  final String label;
  final String? colorHex;
  final bool isPlaying;

  static const Color _fallbackAccent = Color(0xFF3D2E6B);
  static const double _pillHeight = 36;
  static const double _discSize = 34;

  @override
  Widget build(BuildContext context) {
    final accent = giftAccentColor(colorHex, fallback: _fallbackAccent);
    final pillFill = accent.withValues(alpha: 0.1);
    final gift = GiftEntity(
      id: 'auction-audio-chip',
      name: label,
      icon: '🎵',
      priceCoins: 0,
      color: colorHex ?? '#3D2E6B',
      type: GiftCatalogType.audio,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: SizedBox(
        height: _pillHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_pillHeight),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: pillFill,
                borderRadius: BorderRadius.circular(_pillHeight),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          letterSpacing: 0.02,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: _discSize,
                      height: _discSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          if (isPlaying) ...[
                            Positioned(
                              top: -2,
                              right: -4,
                              child: Icon(
                                LucideIcons.music,
                                size: 9,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: -8,
                              child: Icon(
                                LucideIcons.music2,
                                size: 7,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                          isPlaying
                              ? SpinningGiftVinylRecordIcon(
                                  gift: gift,
                                  spinning: true,
                                  size: _discSize,
                                  isSelected: true,
                                  showPauseIcon: false,
                                  discStyle: GiftVinylDiscStyle.chip,
                                )
                              : GiftVinylRecordIcon(
                                  gift: gift,
                                  size: _discSize,
                                  isSelected: true,
                                  discStyle: GiftVinylDiscStyle.chip,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
