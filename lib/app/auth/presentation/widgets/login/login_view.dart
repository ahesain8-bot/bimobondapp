import 'package:bimobondapp/app/auth/presentation/widgets/login/login_methods_buttons.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_sign_up_footer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_toolbar.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginView extends StatelessWidget {
  const LoginView({
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.onGooglePressed,
    required this.onApplePressed,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;

  @override
  Widget build(BuildContext context) {
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final backgroundColor = Theme.of(context).colorScheme.surface;

    return Directionality(
      textDirection: textDirection,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p24,
                vertical: AppSizes.p12,
              ),
              child: Column(
                children: [
                  LoginToolbar(isArabic: isArabic, isDark: isDark),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSizes.p32),
                        CustomText(
                          l10n.loginScreenTitle,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          textAlign: TextAlign.start,
                        ),
                        const SizedBox(height: AppSizes.p48),
                        LoginMethodsButtons(
                          l10n: l10n,
                          onGooglePressed: onGooglePressed,
                          onApplePressed: onApplePressed,
                        ),
                      ],
                    ),
                  ),
                  LoginSignUpFooter(l10n: l10n),
                  const SizedBox(height: AppSizes.p16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
