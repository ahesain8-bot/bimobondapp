import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_hero.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_toolbar.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/core/widgets/phone_text_field.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneLoginView extends StatelessWidget {
  const PhoneLoginView({
    required this.formKey,
    required this.l10n,
    required this.isArabic,
    required this.isDark,
    required this.phoneController,
    required this.selectedCountryCode,
    required this.isLoading,
    required this.onCountryCodeChanged,
    required this.onContinuePressed,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AppLocalizations l10n;
  final bool isArabic;
  final bool isDark;
  final TextEditingController phoneController;
  final String selectedCountryCode;
  final bool isLoading;
  final ValueChanged<String> onCountryCodeChanged;
  final VoidCallback onContinuePressed;

  @override
  Widget build(BuildContext context) {
    final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;

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
                    const PhoneLoginHero(),
                    const SizedBox(height: AppSizes.p24),
                    CustomText(
                      l10n.phoneLoginTitle,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: AppSizes.p6),
                    CustomText(
                      l10n.phoneLoginSubtitle,
                      variant: TextVariant.secondary,
                      fontSize: 16,
                    ),
                    const SizedBox(height: AppSizes.p26),
                    PhoneTextField(
                      controller: phoneController,
                      initialCountryCode: selectedCountryCode,
                      onCountryCodeChanged: onCountryCodeChanged,
                      hintText: l10n.phoneHint,
                      isGlassStyle: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.fieldIsRequired(l10n.phoneLabel);
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.p24),
                    LiquidGlassAuthPrimaryButton(
                      onPressed: isLoading ? null : onContinuePressed,
                      enabled: !isLoading,
                      child: isLoading
                          ? const CustomLoadingWidget(size: 40)
                          : CustomText(
                              l10n.continueAction,
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                    ),
                    const SizedBox(height: AppSizes.p24),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          CustomText(
                            l10n.termsAndConditionsPart1,
                            variant: TextVariant.secondary,
                            fontSize: 12,
                            textAlign: TextAlign.center,
                          ),
                          CustomText(
                            l10n.termsAndConditionsPart2,
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ],
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
