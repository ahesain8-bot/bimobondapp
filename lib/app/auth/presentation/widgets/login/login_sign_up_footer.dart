import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginSignUpFooter extends StatelessWidget {
  const LoginSignUpFooter({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CustomText(
          l10n.dontHaveAccount,
          variant: TextVariant.secondary,
          fontSize: 15,
        ),
        GestureDetector(
          onTap: () => context.pushNamed('signup'),
          child: CustomText(
            l10n.signUp,
            color: secondaryColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
