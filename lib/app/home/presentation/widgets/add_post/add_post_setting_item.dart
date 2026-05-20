import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AddPostSettingItem extends StatelessWidget {
  const AddPostSettingItem({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: CustomText(
                title,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
