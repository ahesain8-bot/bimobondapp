import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AuctionsActiveHeader extends StatelessWidget {
  const AuctionsActiveHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p10,
            vertical: AppSizes.p4,
          ),
          decoration: BoxDecoration(
            color: AppTheme.successAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSizes.radiusCircular),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.successAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSizes.p6),
              CustomText(
                l10n.liveBadge,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.successAccent,
              ),
            ],
          ),
        ),
        const Spacer(),
        CustomText(
          l10n.activeAuctionsNow,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }
}
