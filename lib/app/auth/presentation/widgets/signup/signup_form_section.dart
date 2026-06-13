import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SignUpFormSection extends StatelessWidget {
  const SignUpFormSection({
    required this.l10n,
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.onSignUpPressed,
    super.key,
  });

  final AppLocalizations l10n;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final VoidCallback onSignUpPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiquidGlassAuthTextField(
          controller: fullNameController,
          hintText: l10n.fullNameLabel,
          icon: LucideIcons.user,
          keyboardType: TextInputType.name,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.fieldIsRequired(l10n.fullNameLabel);
            }
            return null;
          },
        ),
        const SizedBox(height: AppSizes.p16),
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
        const SizedBox(height: AppSizes.p16),
        LiquidGlassAuthPasswordField(
          controller: passwordController,
          hintText: l10n.passwordLabel,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.passwordRequired;
            }
            if (value.length < 6) {
              return l10n.passwordTooShort;
            }
            return null;
          },
        ),
        const SizedBox(height: AppSizes.p16),
        LiquidGlassAuthPasswordField(
          controller: confirmPasswordController,
          hintText: l10n.confirmPasswordLabel,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.fieldIsRequired(l10n.confirmPasswordLabel);
            }
            if (value != passwordController.text) {
              return l10n.passwordsDoNotMatch;
            }
            return null;
          },
        ),
        const SizedBox(height: AppSizes.p24),
        LiquidGlassAuthPrimaryButton(
          onPressed: isLoading ? null : onSignUpPressed,
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
      ],
    );
  }
}
