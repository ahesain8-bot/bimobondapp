import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/utils/post_signup_navigation.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/custom_text_field.dart';
import 'package:bimobondapp/core/widgets/custom_button.dart';
import 'package:bimobondapp/core/widgets/directional_back_icon.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';

import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController otpController = TextEditingController();
  bool _isSubmitting = false;

  void _onSubmitPressed() {
    final code = otpController.text.trim();
    if (code.length == 6) {
      setState(() {
        _isSubmitting = true;
      });
      context.read<AuthBloc>().add(
        SubmitOtpEvent(verificationId: widget.verificationId, smsCode: code),
      );
    }
  }

  String _getLocalizedMessage(AppLocalizations l10n, String key) {
    switch (key) {
      case 'loginFailed':
        return l10n.loginFailed;
      case 'verificationFailed':
        return l10n.verificationFailed;
      case 'invalidOtpCode':
        return l10n.invalidOtpCode;
      case 'googleLoginFailed':
        return l10n.googleLoginFailed;
      case 'updateProfileFailed':
        return l10n.updateProfileFailed;
      case 'signupFailed':
        return l10n.signupFailed;
      default:
        return key; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => context.pop(),
          icon: DirectionalBackIcon(
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
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthFailure || current is AuthSuccess,
        listener: (context, state) {
          if (!_isSubmitting) return;

          if (state is AuthFailure) {
            _isSubmitting = false;
            String message = state.messageKey != null
                ? _getLocalizedMessage(l10n, state.messageKey!)
                : state.message;
            PopupDialogs.showErrorDialog(context, message);
          } else if (state is AuthSuccess) {
            _isSubmitting = false;
            navigateAfterSignUp(context);
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.p20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.p24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.mailCheck,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p32),
                CustomText(
                  l10n.verifyPhoneTitle,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: AppSizes.p8),
                CustomText(
                  '${l10n.enterCodeSentTo} ${widget.phoneNumber}',
                  variant: TextVariant.secondary,
                  fontSize: 16,
                ),
                const SizedBox(height: AppSizes.p48),
                CustomText(
                  l10n.verificationCodeLabel,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                const SizedBox(height: AppSizes.p8),
                CustomTextField(
                  controller: otpController,
                  hintText: '000000',
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  // maxLength: 6, // If CustomTextField supports it
                ),
                const SizedBox(height: AppSizes.p32),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return CustomButton(
                      text: l10n.verifyAndLoginBtn,
                      isLoading: state is AuthLoading,
                      onPressed: _onSubmitPressed,
                    );
                  },
                ),
                const SizedBox(height: AppSizes.p24),
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Implement resend logic if needed
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomText(
                          l10n.didNotReceiveCode,
                          variant: TextVariant.secondary,
                          fontSize: 14,
                        ),
                        CustomText(
                          l10n.resendCode,
                          color: theme.colorScheme.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
