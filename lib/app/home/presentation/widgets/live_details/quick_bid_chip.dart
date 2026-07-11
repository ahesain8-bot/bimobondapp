import 'dart:ui';

import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:bimobondapp/core/utils/locale_format_utils.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class QuickBidChip extends StatelessWidget {
  const QuickBidChip({
    required this.amount,
    required this.label,
    required this.onTap,
  });

  final int amount;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          LiveDetailsLayoutConstants.quickBidRadius,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: AppSizes.p8,
            ),
            decoration: BoxDecoration(
              color: LiveDetailsLayoutConstants.glassFill,
              borderRadius: BorderRadius.circular(
                LiveDetailsLayoutConstants.quickBidRadius,
              ),
              border: Border.all(color: LiveDetailsLayoutConstants.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppCoinIcon(size: 16),
                const SizedBox(width: AppSizes.p4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
