import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthCredentialsFormSection extends StatelessWidget {
  const AuthCredentialsFormSection({
    required this.l10n,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.submitLabel,
    required this.onSubmit,
    super.key,
  });

  final AppLocalizations l10n;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final String submitLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: AppSizes.p8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () {
              final email = emailController.text.trim();
              context.pushNamed(
                'forgot_password',
                queryParameters: email.isNotEmpty ? {'email': email} : const {},
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: CustomText(
              l10n.forgotPassword,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.p16),
        LiquidGlassAuthPrimaryButton(
          onPressed: isLoading ? null : onSubmit,
          enabled: !isLoading,
          child: isLoading
              ? const CustomLoadingWidget(size: 40)
              : CustomText(
                  submitLabel,
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
        ),
      ],
    );
  }
}
