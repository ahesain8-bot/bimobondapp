import 'dart:ui';

import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p12,
            vertical: AppSizes.p6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.6),
                Colors.black.withValues(alpha: 0.4),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.p4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.clock,
                    size: 14,
                    color: accentColor,
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
    );
  }
}
