import 'package:bimobondapp/app/auth/presentation/widgets/auth/auth_legal_note.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginSignUpFooter extends StatelessWidget {
  const LoginSignUpFooter({required this.l10n, super.key});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthLegalNote(l10n: l10n),
        const SizedBox(height: AppSizes.p16),
        Row(
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
                color: primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
