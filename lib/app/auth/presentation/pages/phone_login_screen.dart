import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/custom_text_field.dart';
import 'package:bimobondapp/core/widgets/phone_text_field.dart';
import 'package:bimobondapp/core/widgets/custom_button.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  String _selectedCountryCode = '+20';
  bool _isSubmitting = false;

  void _onVerifyPressed() {
    final phone = phoneController.text.trim();
    if (phone.isNotEmpty) {
      setState(() {
        _isSubmitting = true;
      });
      final fullPhoneNumber = '$_selectedCountryCode$phone';
      context.read<AuthBloc>().add(
        VerifyPhoneEvent(phoneNumber: fullPhoneNumber),
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
      case 'facebookLoginFailed':
        return l10n.facebookLoginFailed;
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
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthFailure || current is PhoneCodeSentState,
        listener: (context, state) {
          if (!_isSubmitting) return;

          if (state is AuthFailure) {
            _isSubmitting = false;
            String message = state.messageKey != null
                ? _getLocalizedMessage(l10n, state.messageKey!)
                : state.message;
            PopupDialogs.showErrorDialog(context, message);
          } else if (state is PhoneCodeSentState) {
            _isSubmitting = false;
            context.pushNamed(
              'otp_verify',
              queryParameters: {
                'verificationId': state.verificationId,
                'phoneNumber': phoneController.text.trim(),
              },
            );
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
                    padding: const EdgeInsets.all(AppSizes.p16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      AppAssets.phoneAuth,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.p32),
                CustomText(
                  l10n.phoneLoginTitle,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: AppSizes.p8),
                CustomText(
                  l10n.phoneLoginSubtitle,
                  variant: TextVariant.secondary,
                  fontSize: 16,
                ),
                const SizedBox(height: AppSizes.p48),
                PhoneTextField(
                  controller: phoneController,
                  initialCountryCode: _selectedCountryCode,
                  onCountryCodeChanged: (code) {
                    setState(() {
                      _selectedCountryCode = code;
                    });
                  },
                  hintText: l10n.phoneHint,
                  labelText: l10n.phoneLabel,
                ),
                const SizedBox(height: AppSizes.p32),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    return CustomButton(
                      text: l10n.continueAction,
                      isLoading: state is AuthLoading,
                      onPressed: _onVerifyPressed,
                    );
                  },
                ),
                const SizedBox(height: AppSizes.p24),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      CustomText(
                        l10n.termsAndConditionsPart1,
                        variant: TextVariant.secondary,
                        fontSize: 12,
                        textAlign: TextAlign.center,
                      ),
                      CustomText(
                        l10n.termsAndConditionsPart2,
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
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

// Helper for Circle shape in decoration since BoxType.circle is not standard
extension on BoxDecoration {
  static const BoxShape circle = BoxShape.circle;
}
