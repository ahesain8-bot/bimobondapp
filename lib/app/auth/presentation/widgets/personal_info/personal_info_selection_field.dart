import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class PersonalInfoSelectionField extends StatelessWidget {
  const PersonalInfoSelectionField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    super.key,
  });

  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: CustomText(
                label,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: CustomText(
                value ?? hint,
                fontSize: 15,
                color: value == null
                    ? theme.disabledColor.withValues(alpha: 0.5)
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
            Icon(
              isRTL ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
              size: 16,
              color: theme.disabledColor.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
