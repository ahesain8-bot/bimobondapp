import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_digits.dart';
import 'package:bimobondapp/app/home/presentation/widgets/live_details/auction_countdown_parts.dart';

class AuctionCountdownBar extends StatelessWidget {
  const AuctionCountdownBar({required this.parts});

  final AuctionCountdownParts parts;

  @override
  Widget build(BuildContext context) {
    final accentColor = parts.isFinished
        ? LiveDetailsLayoutConstants.auctionFinishedBadgeColor
        : parts.isUpcoming
            ? Colors.amberAccent
            : LiveDetailsLayoutConstants.auctionActiveBadgeColor;

    final radius = LiveDetailsLayoutConstants.countdownBarRadius;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: LiveDetailsLayoutConstants.countdownBarBlur,
          sigmaY: LiveDetailsLayoutConstants.countdownBarBlur,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p8,
            vertical: AppSizes.p6,
          ),
          decoration: BoxDecoration(
            color: LiveDetailsLayoutConstants.countdownBarOverlay,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: LiveDetailsLayoutConstants.countdownBarBorder,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: LiveDetailsLayoutConstants.countdownBarFill,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p6,
                vertical: AppSizes.p4,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: AppSizes.p6),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: parts.isFinished ? 0.5 : 0.9,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSizes.p8),
                      AuctionCountdownDigits(
                        parts: parts,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
