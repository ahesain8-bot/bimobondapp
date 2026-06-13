import 'package:bimobondapp/app/auth/presentation/widgets/auth/auth_credentials_form_section.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class LoginFormSection extends StatelessWidget {
  const LoginFormSection({
    required this.l10n,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLoginPressed,
    super.key,
  });

  final AppLocalizations l10n;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return AuthCredentialsFormSection(
      l10n: l10n,
      emailController: emailController,
      passwordController: passwordController,
      isLoading: isLoading,
      submitLabel: l10n.loginButton,
      onSubmit: onLoginPressed,
    );
  }
}
