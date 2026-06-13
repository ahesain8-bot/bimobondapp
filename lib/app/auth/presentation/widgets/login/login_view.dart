import 'package:bimobondapp/app/auth/presentation/widgets/login/login_form_section.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_header.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_sign_up_footer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_social_section.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_toolbar.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginView extends StatelessWidget {
  const LoginView({
    required this.formKey,
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLoginPressed,
    required this.onGooglePressed,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLoginPressed;
  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    return Directionality(
      textDirection: textDirection,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: scaffoldColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.p24,
                vertical: AppSizes.p12,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoginToolbar(isArabic: isArabic, isDark: isDark),
                    const SizedBox(height: AppSizes.p8),
                    LoginHeader(l10n: l10n),
                    const SizedBox(height: AppSizes.p26),
                    LoginFormSection(
                      l10n: l10n,
                      emailController: emailController,
                      passwordController: passwordController,
                      isLoading: isLoading,
                      onLoginPressed: onLoginPressed,
                    ),
                    const SizedBox(height: AppSizes.p24),
                    LoginSocialSection(
                      l10n: l10n,
                      onGooglePressed: onGooglePressed,
                    ),
                    const SizedBox(height: AppSizes.p32),
                    LoginSignUpFooter(l10n: l10n),
                    const SizedBox(height: AppSizes.p24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
