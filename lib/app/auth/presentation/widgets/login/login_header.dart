import 'package:bimobondapp/app/auth/presentation/widgets/auth/auth_screen_header.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AuthScreenHeader(
      title: l10n.loginTitle,
      subtitle: l10n.signInSubtitle,
    );
  }
}
