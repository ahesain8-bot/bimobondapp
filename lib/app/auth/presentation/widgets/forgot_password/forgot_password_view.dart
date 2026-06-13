import 'package:bimobondapp/app/auth/presentation/widgets/forgot_password/forgot_password_hero.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_toolbar.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({
    required this.formKey,
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.emailController,
    required this.isLoading,
    required this.onSubmitPressed,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSubmitPressed;

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
                    const ForgotPasswordHero(),
                    const SizedBox(height: AppSizes.p24),
                    CustomText(
                      l10n.forgotPasswordTitle,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: AppSizes.p6),
                    CustomText(
                      l10n.forgotPasswordSubtitle,
                      variant: TextVariant.secondary,
                      fontSize: 16,
                    ),
                    const SizedBox(height: AppSizes.p26),
                    LiquidGlassAuthTextField(
                      controller: emailController,
                      hintText: l10n.emailLabel,
                      icon: Icons.email_outlined,
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
                    const SizedBox(height: AppSizes.p24),
                    LiquidGlassAuthPrimaryButton(
                      onPressed: isLoading ? null : onSubmitPressed,
                      enabled: !isLoading,
                      child: isLoading
                          ? const CustomLoadingWidget(size: 40)
                          : CustomText(
                              l10n.forgotPasswordButton,
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
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
