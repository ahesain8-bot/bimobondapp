import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChangeAvatarOptionTile extends StatelessWidget {
  const ChangeAvatarOptionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p24,
          vertical: AppSizes.p16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive ? Colors.red : theme.iconTheme.color,
            ),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              child: CustomText(
                label,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : null,
              ),
            ),
            Icon(
              isRTL ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
              size: 18,
              color: theme.disabledColor.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
