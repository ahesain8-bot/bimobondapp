import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class LoginMethodsButtons extends StatelessWidget {
  const LoginMethodsButtons({
    required this.l10n,
    required this.onGooglePressed,
    required this.onApplePressed,
    this.emailRouteName = 'email_login',
    super.key,
  });

  final AppLocalizations l10n;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final String emailRouteName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = theme.colorScheme.surface;
    final borderColor = theme.brightness == Brightness.dark
        ? const Color(0x33FFFFFF)
        : const Color(0xFFE3E3E3);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LoginMethodButton(
          label: l10n.loginWithPhone,
          backgroundColor: buttonColor,
          borderColor: borderColor,
          onPressed: () => context.pushNamed('phone_login'),
          icon: SvgPicture.asset(
            AppAssets.mobileIcon,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
          ),
        ),
        const SizedBox(height: AppSizes.p12),
        _LoginMethodButton(
          label: l10n.loginWithEmailUsername,
          backgroundColor: buttonColor,
          borderColor: borderColor,
          onPressed: () => context.pushNamed(emailRouteName),
          icon: Icon(Icons.alternate_email_rounded, size: 22, color: onSurface),
        ),
        const SizedBox(height: AppSizes.p12),
        _LoginMethodButton(
          label: l10n.continueWithGoogle,
          backgroundColor: buttonColor,
          borderColor: borderColor,
          onPressed: onGooglePressed,
          icon: SvgPicture.asset(AppAssets.googleIcon, width: 22, height: 22),
        ),
        const SizedBox(height: AppSizes.p12),
        _LoginMethodButton(
          label: l10n.continueWithApple,
          backgroundColor: buttonColor,
          borderColor: borderColor,
          onPressed: onApplePressed,
          icon: Icon(Icons.apple, size: 24, color: onSurface),
        ),
      ],
    );
  }
}

class _LoginMethodButton extends StatelessWidget {
  const _LoginMethodButton({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.onPressed,
    required this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.authControlHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: icon),
            CustomText(
              label,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
