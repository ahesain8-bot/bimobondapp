import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class ProfileStatItem extends StatelessWidget {
  const ProfileStatItem({
    required this.number,
    required this.label,
    this.onTap,
    super.key,
  });

  final String number;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: secondary,
          ),
        ),
      ],
    );

    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p8,
        vertical: AppSizes.p4,
      ),
      child: Center(child: content),
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: child,
    );
  }
}
