import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignUpLoginFooter extends StatelessWidget {
  const SignUpLoginFooter({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomText(
          l10n.alreadyHaveAccount,
          variant: TextVariant.secondary,
          fontSize: 15,
        ),
        GestureDetector(
          onTap: () => context.pop(),
          child: CustomText(
            l10n.loginTitle,
            color: primaryColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
