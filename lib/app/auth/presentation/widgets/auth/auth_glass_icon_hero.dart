import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';

class AuthGlassIconHero extends StatelessWidget {
  const AuthGlassIconHero({
    required this.icon,
    this.iconSize = 55,
    this.boxSize = 99,
    super.key,
  });

  final IconData icon;
  final double iconSize;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SizedBox(
        height: 160,
        width: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(
                      alpha: isDark ? 0.24 : 0.16,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(22),
              blurSigma: 16,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.14),
              borderColor: AppTheme.primaryColor.withValues(alpha: 0.32),
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
