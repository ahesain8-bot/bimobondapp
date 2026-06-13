import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Image.asset(
            'assets/images/logo.png',
            width: 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              LucideIcons.circleMinus,
              size: 100,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.p16),
        CustomText(
          title,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        ),
        const SizedBox(height: AppSizes.p6),
        CustomText(
          subtitle,
          variant: TextVariant.secondary,
          fontSize: 16,
        ),
      ],
    );
  }
}
