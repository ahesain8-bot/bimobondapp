import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AddPostSettingItem extends StatelessWidget {
  const AddPostSettingItem({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = iconColor ?? colorScheme.primary;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.p12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: CustomText(
                      title,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 50,
            color: theme.dividerColor.withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
