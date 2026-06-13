import 'package:bimobondapp/app/auth/presentation/widgets/signup/signup_form_section.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/auth/auth_screen_header.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_toolbar.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/signup/signup_login_footer.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SignUpView extends StatelessWidget {
  const SignUpView({
    required this.formKey,
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSignUpPressed,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSignUpPressed;

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
                    AuthScreenHeader(
                      title: l10n.signUpTitle,
                      subtitle: l10n.signUpSubtitle,
                    ),
                    const SizedBox(height: AppSizes.p26),
                    SignUpFormSection(
                      l10n: l10n,
                      fullNameController: fullNameController,
                      emailController: emailController,
                      passwordController: passwordController,
                      confirmPasswordController: confirmPasswordController,
                      isLoading: isLoading,
                      onSignUpPressed: onSignUpPressed,
                    ),
                    const SizedBox(height: AppSizes.p32),
                    SignUpLoginFooter(l10n: l10n),
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
