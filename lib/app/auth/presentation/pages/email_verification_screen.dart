import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/email_verification/email_verification_hero.dart';
import 'package:bimobondapp/core/widgets/custom_button.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isChecking = false;
  bool isResending = false;

  Future<void> _resendVerificationEmail() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() => isResending = true);

    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user == null) {
        PopupDialogs.showErrorDialog(
          context,
          l10n.emailVerificationResendError,
        );
        return;
      }

      await user.sendEmailVerification();
      PopupDialogs.showSuccessDialog(
        context,
        l10n.emailVerificationResendSuccess,
      );
    } catch (e) {
      PopupDialogs.showErrorDialog(context, l10n.emailVerificationResendFailed);
    } finally {
      if (mounted) {
        setState(() => isResending = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() => isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        PopupDialogs.showErrorDialog(
          context,
          l10n.emailVerificationStatusError,
        );
        return;
      }

      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null && updatedUser.emailVerified) {
        context.goNamed('home');
      } else {
        PopupDialogs.showErrorDialog(
          context,
          l10n.emailVerificationNotVerified,
        );
      }
    } catch (e) {
      PopupDialogs.showErrorDialog(context, l10n.emailVerificationCheckFailed);
    } finally {
      if (mounted) {
        setState(() => isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          label: CustomText(
            l10n.back,
            color: theme.colorScheme.onSurface,
            fontSize: 16,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSizes.p24),
              const EmailVerificationHero(),
              const SizedBox(height: AppSizes.p32),
              CustomText(
                l10n.emailVerificationTitle,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: AppSizes.p12),
              CustomText(
                l10n.emailVerificationSent(widget.email),
                variant: TextVariant.secondary,
                fontSize: 16,
              ),
              const SizedBox(height: AppSizes.p8),
              CustomText(
                l10n.emailVerificationContinue,
                variant: TextVariant.secondary,
                fontSize: 16,
              ),
              const SizedBox(height: AppSizes.p24),
              CustomButton(
                text: l10n.emailVerificationButton,
                isLoading: isChecking,
                onPressed: _checkVerificationStatus,
              ),
              // const SizedBox(height: AppSizes.p16),
              // Center(
              //   child: TextButton(
              //     onPressed: isResending ? null : _resendVerificationEmail,
              //     child: CustomText(
              //       isResending
              //           ? l10n.emailVerificationResending
              //           : l10n.emailVerificationResendButton,
              //       color: theme.colorScheme.primary,
              //       fontSize: 14,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
