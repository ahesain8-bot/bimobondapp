import 'package:flutter/material.dart';

import '../../../../core/utils/app_colors.dart';
import '../../../../core/utils/app_sizes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/app_text_styles.dart';

/// Interaction menu shown from the start-live tools.
class StartLiveInteractionSheet {
  const StartLiveInteractionSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.shareScrim,
      builder: (_) => const _InteractionSheetBody(),
    );
  }
}

class _InteractionSheetBody extends StatelessWidget {
  const _InteractionSheetBody();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: AppColors.optionsSheetBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.shareSheetRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.shareSheetHorizontal,
                      AppSpacing.sm,
                      AppSpacing.shareSheetHorizontal,
                      AppSpacing.md,
                    ),
                    child: Text('التفاعل', style: AppTextStyles.shareTitle),
                  ),
                  const _InteractionCard(
                    title: 'اقتراحات',
                    icon: Icons.card_giftcard_outlined,
                  ),
                  const SizedBox(height: AppSpacing.smd),
                  const _InteractionCard(
                    title: 'الدليل الإرشادي',
                    icon: Icons.menu_book_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InteractionCard extends StatelessWidget {
  const _InteractionCard({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {},
          child: SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 49,
                    height: 49,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F8F8),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: AppColors.optionsForeground,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.optionsForeground,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
