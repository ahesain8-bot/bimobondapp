import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class AuthLegalNote extends StatelessWidget {
  const AuthLegalNote({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final linkColor = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CustomText(
          l10n.loginLegalNotePart1,
          variant: TextVariant.secondary,
          fontSize: 12,
          textAlign: TextAlign.center,
        ),
        CustomText(
          l10n.loginTermsOfService,
          color: linkColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        CustomText(
          l10n.loginLegalNotePart2,
          variant: TextVariant.secondary,
          fontSize: 12,
          textAlign: TextAlign.center,
        ),
        CustomText(
          l10n.loginPrivacyPolicy,
          color: linkColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ],
    );
  }
}
