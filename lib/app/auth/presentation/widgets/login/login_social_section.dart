import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class LoginSocialSection extends StatelessWidget {
  const LoginSocialSection({
    required this.l10n,
    required this.onGooglePressed,
    super.key,
  });

  final AppLocalizations l10n;
  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
              child: CustomText(
                l10n.continueWith,
                variant: TextVariant.secondary,
                fontSize: 14,
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSizes.p24),
        Row(
          children: [
            Expanded(
              child: LiquidGlassAuthOutlinedButton(
                onPressed: () => context.pushNamed('phone_login'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.mobileIcon,
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CustomText(
                      l10n.mobileNumberLabel,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSizes.p12),
            LiquidGlassAuthIconButton(
              onPressed: onGooglePressed,
              child: SvgPicture.asset(
                AppAssets.googleIcon,
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: AppSizes.p12),
            LiquidGlassAuthIconButton(
              onPressed: () {},
              child: Icon(
                Icons.apple,
                size: 28,
                color: onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
