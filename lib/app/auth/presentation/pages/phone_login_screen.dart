import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_view.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  String _selectedCountryCode = '+20';
  bool _isSubmitting = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _onVerifyPressed() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final fullPhoneNumber = '$_selectedCountryCode${phoneController.text.trim()}';
    context.read<AuthBloc>().add(
      VerifyPhoneEvent(phoneNumber: fullPhoneNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final l10n = AppLocalizations.of(context)!;
        final isArabic = locale.languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthFailure || current is PhoneCodeSentState,
          listener: (context, state) {
            if (!_isSubmitting) return;

            if (state is AuthFailure) {
              setState(() => _isSubmitting = false);
              final message = state.messageKey != null
                  ? localizeAuthMessage(l10n, state.messageKey!)
                  : state.message;
              PopupDialogs.showErrorDialog(context, message);
            } else if (state is PhoneCodeSentState) {
              setState(() => _isSubmitting = false);
              context.pushNamed(
                'otp_verify',
                queryParameters: {
                  'verificationId': state.verificationId,
                  'phoneNumber': phoneController.text.trim(),
                },
              );
            }
          },
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              return PhoneLoginView(
                formKey: _formKey,
                l10n: l10n,
                isArabic: isArabic,
                isDark: isDark,
                phoneController: phoneController,
                selectedCountryCode: _selectedCountryCode,
                isLoading: state is AuthLoading,
                onCountryCodeChanged: (code) {
                  setState(() => _selectedCountryCode = code);
                },
                onContinuePressed: _onVerifyPressed,
              );
            },
          ),
        );
      },
    );
  }
}
