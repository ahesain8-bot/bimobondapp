import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/directional_chevron_icon.dart';
import 'package:flutter/material.dart';

/// Flat TikTok-style settings row (icon + title + trailing chevron).
class AddPostSettingItem extends StatelessWidget {
  const AddPostSettingItem({
    required this.icon,
    required this.title,
    this.trailing,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.showDivider = true,
    this.showChevron = true,
    this.below,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showDivider;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: iconColor ?? onSurface),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          title,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          CustomText(
                            subtitle!,
                            fontSize: 12,
                            variant: TextVariant.secondary,
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                  if (showChevron) ...[
                    const SizedBox(width: 4),
                    DirectionalChevronIcon(
                      size: 18,
                      color: muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (below != null) below!,
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 52,
            color: theme.dividerColor.withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
