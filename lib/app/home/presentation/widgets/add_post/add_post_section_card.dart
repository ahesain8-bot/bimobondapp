import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';

class AddPostSectionCard extends StatelessWidget {
  const AddPostSectionCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSizes.p16),
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.55);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: CustomText(
                      title!,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: AppSizes.p12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
