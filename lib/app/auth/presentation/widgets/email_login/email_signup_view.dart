import 'package:bimobondapp/app/auth/presentation/widgets/auth/password_requirements_checklist.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/auth/password_strength_indicator.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_toolbar.dart';
import 'package:bimobondapp/core/utils/password_strength.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum EmailSignUpStep { email, name, password }

class EmailSignUpView extends StatelessWidget {
  const EmailSignUpView({
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.currentStep,
    required this.emailFormKey,
    required this.nameFormKey,
    required this.passwordFormKey,
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onBackPressed,
    required this.onNextPressed,
    required this.onSignUpPressed,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final EmailSignUpStep currentStep;
  final GlobalKey<FormState> emailFormKey;
  final GlobalKey<FormState> nameFormKey;
  final GlobalKey<FormState> passwordFormKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onBackPressed;
  final VoidCallback onNextPressed;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhoneLoginToolbar(
                    isArabic: isArabic,
                    isDark: isDark,
                    onBackPressed: onBackPressed,
                  ),
                  const SizedBox(height: AppSizes.p32),
                  CustomText(
                    _titleForStep(l10n),
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                  if (_subtitleForStep(l10n) != null) ...[
                    const SizedBox(height: AppSizes.p6),
                    CustomText(
                      _subtitleForStep(l10n)!,
                      variant: TextVariant.secondary,
                      fontSize: 16,
                    ),
                  ],
                  const SizedBox(height: AppSizes.p26),
                  switch (currentStep) {
                    EmailSignUpStep.email => _EmailStep(
                        formKey: emailFormKey,
                        l10n: l10n,
                        emailController: emailController,
                        isLoading: isLoading,
                        onNextPressed: onNextPressed,
                      ),
                    EmailSignUpStep.name => _NameStep(
                        formKey: nameFormKey,
                        l10n: l10n,
                        fullNameController: fullNameController,
                        isLoading: isLoading,
                        onNextPressed: onNextPressed,
                      ),
                    EmailSignUpStep.password => _PasswordStep(
                        formKey: passwordFormKey,
                        l10n: l10n,
                        passwordController: passwordController,
                        isLoading: isLoading,
                        onSignUpPressed: onSignUpPressed,
                      ),
                  },
                  const SizedBox(height: AppSizes.p24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _titleForStep(AppLocalizations l10n) {
    return switch (currentStep) {
      EmailSignUpStep.email => l10n.signUpEmailStepTitle,
      EmailSignUpStep.name => l10n.signUpNameStepTitle,
      EmailSignUpStep.password => l10n.signUpPasswordStepTitle,
    };
  }

  String? _subtitleForStep(AppLocalizations l10n) {
    return switch (currentStep) {
      EmailSignUpStep.email => l10n.signUpSubtitle,
      EmailSignUpStep.name => null,
      EmailSignUpStep.password => null,
    };
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.formKey,
    required this.l10n,
    required this.emailController,
    required this.isLoading,
    required this.onNextPressed,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onNextPressed;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiquidGlassAuthTextField(
            controller: emailController,
            hintText: l10n.emailLabel,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.emailRequired;
              }
              final emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              if (!emailRegex.hasMatch(value)) {
                return l10n.invalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSizes.p16),
          CustomText(
            l10n.emailLoginUsageNote,
            variant: TextVariant.secondary,
            fontSize: 12,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: AppSizes.p24),
          LiquidGlassAuthPrimaryButton(
            onPressed: isLoading ? null : onNextPressed,
            enabled: !isLoading,
            child: CustomText(
              l10n.nextAction,
              color: Colors.white,
              fontSize: AppSizes.authControlFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.formKey,
    required this.l10n,
    required this.fullNameController,
    required this.isLoading,
    required this.onNextPressed,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final TextEditingController fullNameController;
  final bool isLoading;
  final VoidCallback onNextPressed;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiquidGlassAuthTextField(
            controller: fullNameController,
            hintText: l10n.fullNameLabel,
            keyboardType: TextInputType.name,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.fieldIsRequired(l10n.fullNameLabel);
              }
              return null;
            },
          ),
          const SizedBox(height: AppSizes.p24),
          LiquidGlassAuthPrimaryButton(
            onPressed: isLoading ? null : onNextPressed,
            enabled: !isLoading,
            child: CustomText(
              l10n.nextAction,
              color: Colors.white,
              fontSize: AppSizes.authControlFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.formKey,
    required this.l10n,
    required this.passwordController,
    required this.isLoading,
    required this.onSignUpPressed,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSignUpPressed;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiquidGlassAuthPasswordField(
            controller: passwordController,
            hintText: l10n.passwordLabel,
            maxLength: PasswordRequirements.maxLength,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.passwordRequired;
              }
              if (value.length > 20) {
                return l10n.passwordTooLong;
              }
              final requirements = PasswordRequirements.evaluate(value);
              if (!requirements.isValid) {
                return l10n.passwordRequirementsNotMet;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSizes.p12),
          PasswordRequirementsChecklist(
            controller: passwordController,
            l10n: l10n,
          ),
          const SizedBox(height: AppSizes.p12),
          PasswordStrengthIndicator(
            controller: passwordController,
            l10n: l10n,
          ),
          const SizedBox(height: AppSizes.p24),
          LiquidGlassAuthPrimaryButton(
            onPressed: isLoading ? null : onSignUpPressed,
            enabled: !isLoading,
            child: isLoading
                ? const CustomLoadingWidget(size: 40)
                : CustomText(
                    l10n.createAccountBtn,
                    color: Colors.white,
                    fontSize: AppSizes.authControlFontSize,
                    fontWeight: FontWeight.bold,
                  ),
          ),
        ],
      ),
    );
  }
}
