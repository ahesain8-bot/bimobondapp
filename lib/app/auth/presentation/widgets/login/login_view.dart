import 'package:bimobondapp/app/auth/presentation/widgets/login/login_form_section.dart';
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
    required this.showEmailForm,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onEmailMethodPressed,
    required this.onBackFromEmailPressed,
    required this.onLoginPressed,
    required this.onGooglePressed,
    required this.onApplePressed,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final bool showEmailForm;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onEmailMethodPressed;
  final VoidCallback onBackFromEmailPressed;
  final VoidCallback onLoginPressed;
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
            child: showEmailForm
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p24,
                      vertical: AppSizes.p12,
                    ),
                    child: _EmailLoginBody(
                      formKey: formKey,
                      l10n: l10n,
                      emailController: emailController,
                      passwordController: passwordController,
                      isLoading: isLoading,
                      onBackPressed: onBackFromEmailPressed,
                      onLoginPressed: onLoginPressed,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p24,
                      vertical: AppSizes.p12,
                    ),
                    child: _MethodsLoginBody(
                      l10n: l10n,
                      isArabic: isArabic,
                      isDark: isDark,
                      onEmailMethodPressed: onEmailMethodPressed,
                      onGooglePressed: onGooglePressed,
                      onApplePressed: onApplePressed,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MethodsLoginBody extends StatelessWidget {
  const _MethodsLoginBody({
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.onEmailMethodPressed,
    required this.onGooglePressed,
    required this.onApplePressed,
  });

  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final VoidCallback onEmailMethodPressed;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                onEmailUsernamePressed: onEmailMethodPressed,
                onGooglePressed: onGooglePressed,
                onApplePressed: onApplePressed,
              ),
            ],
          ),
        ),
        LoginSignUpFooter(l10n: l10n),
        const SizedBox(height: AppSizes.p16),
      ],
    );
  }
}

class _EmailLoginBody extends StatelessWidget {
  const _EmailLoginBody({
    required this.formKey,
    required this.l10n,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onBackPressed,
    required this.onLoginPressed,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onBackPressed;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: onBackPressed,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ),
            const SizedBox(height: AppSizes.p8),
            CustomText(
              l10n.loginWithEmailUsername,
              fontSize: 28,
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
          ],
        ),
      ),
    );
  }
}
