import 'package:bimobondapp/app/auth/presentation/widgets/login/login_form_section.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_toolbar.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmailLoginView extends StatelessWidget {
  const EmailLoginView({
    required this.formKey,
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLoginPressed,
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
                    PhoneLoginToolbar(isArabic: isArabic, isDark: isDark),
                    const SizedBox(height: AppSizes.p8),
                    const SizedBox(height: AppSizes.p24),
                    CustomText(
                      l10n.loginWithEmailUsername,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: AppSizes.p6),
                    CustomText(
                      l10n.signInSubtitle,
                      variant: TextVariant.secondary,
                      fontSize: 16,
                    ),
                    const SizedBox(height: AppSizes.p26),
                    LoginFormSection(
                      l10n: l10n,
                      emailController: emailController,
                      passwordController: passwordController,
                      isLoading: isLoading,
                      onLoginPressed: onLoginPressed,
                    ),
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
