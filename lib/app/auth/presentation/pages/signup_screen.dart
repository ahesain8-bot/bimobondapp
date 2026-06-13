import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/signup/signup_view.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends StatefulWidget {
  final String language;

  const SignUpScreen({super.key, required this.language});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignUpPressed() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    context.read<AuthBloc>().add(
      SignUpWithEmailEvent(
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final l10n = AppLocalizations.of(context)!;
        final isArabic = locale.languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return BlocConsumer<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current is AuthFailure ||
              current is AuthSuccess ||
              current is EmailVerificationSentState ||
              current is EmailOtpSentState,
          listener: (context, state) {
            if (!_isSubmitting) return;

            if (state is AuthFailure) {
              setState(() => _isSubmitting = false);
              final message = state.messageKey != null
                  ? localizeAuthMessage(l10n, state.messageKey!)
                  : state.message;
              PopupDialogs.showErrorDialog(context, message);
            } else if (state is EmailVerificationSentState) {
              setState(() => _isSubmitting = false);
              context.pushReplacementNamed(
                'email_verification',
                queryParameters: {'email': state.email},
              );
            } else if (state is AuthSuccess) {
              setState(() => _isSubmitting = false);
              context.pushReplacementNamed('home');
            } else if (state is EmailOtpSentState) {
              setState(() => _isSubmitting = false);
              context.pushNamed(
                'email_otp_verify',
                queryParameters: {'email': state.email},
              );
            }
          },
          builder: (context, state) {
            return SignUpView(
              formKey: _formKey,
              l10n: l10n,
              isArabic: isArabic,
              isDark: isDark,
              fullNameController: fullNameController,
              emailController: emailController,
              passwordController: passwordController,
              confirmPasswordController: confirmPasswordController,
              isLoading: _isSubmitting || state is AuthLoading,
              onSignUpPressed: _onSignUpPressed,
            );
          },
        );
      },
    );
  }
}
