import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';

class PhoneLoginHero extends StatelessWidget {
  const PhoneLoginHero({super.key});

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SizedBox(
        height: 220,
        width: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFF38BDF8,
                    ).withValues(alpha: isDark ? 0.28 : 0.22),
                    const Color(
                      0xFFEC4899,
                    ).withValues(alpha: isDark ? 0.18 : 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Image.asset(
              AppAssets.phoneMockup,
              height: 170,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ),
    );
  }
}
