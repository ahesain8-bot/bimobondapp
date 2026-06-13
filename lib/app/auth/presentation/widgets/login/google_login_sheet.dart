import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class GoogleLoginSheet {
  GoogleLoginSheet._();

  static Future<bool> show(BuildContext context) async {
    final confirmed = await GlassBottomSheet.showContent<bool>(
      context,
      adaptTheme: true,
      isScrollControlled: true,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.p16,
        0,
        AppSizes.p16,
        AppSizes.p24,
      ),
      child: const _GoogleLoginSheetBody(),
    );
    return confirmed == true;
  }
}

class _GoogleLoginSheetBody extends StatelessWidget {
  const _GoogleLoginSheetBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: LiquidGlassSurface(
            borderRadius: BorderRadius.circular(20),
            backgroundColor: Colors.white.withValues(alpha: 0.14),
            borderColor: Colors.white.withValues(alpha: 0.28),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.p16),
              child: SvgPicture.asset(
                AppAssets.googleIcon,
                width: 40,
                height: 40,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.p20),
        Text(
          l10n.googleLoginSheetTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppSizes.p8),
        Text(
          l10n.googleLoginSheetSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSizes.p24),
        LiquidGlassSurface(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          backgroundColor: Colors.transparent,
          borderColor: Colors.white.withValues(alpha: 0.28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context, true),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              child: SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.googleIcon,
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: AppSizes.p10),
                    Text(
                      l10n.googleLoginContinue,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.p8),
        LiquidGlassSurface(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          backgroundColor: Colors.transparent,
          borderColor: Colors.white.withValues(alpha: 0.28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context, false),
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    l10n.cancel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
