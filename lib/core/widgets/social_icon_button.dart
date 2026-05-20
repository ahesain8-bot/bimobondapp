import 'package:flutter/material.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';

class SocialIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;

  const SocialIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black26,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}
