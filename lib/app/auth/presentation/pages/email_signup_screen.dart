import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/email_login/email_signup_view.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/utils/post_signup_navigation.dart';

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  EmailSignUpStep _currentStep = EmailSignUpStep.email;
  bool _isSubmitting = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onBackPressed() {
    if (_currentStep == EmailSignUpStep.email) {
      context.pop();
      return;
    }

    setState(() {
      _currentStep = switch (_currentStep) {
        EmailSignUpStep.name => EmailSignUpStep.email,
        EmailSignUpStep.password => EmailSignUpStep.name,
        EmailSignUpStep.email => EmailSignUpStep.email,
      };
    });
  }

  void _onNextPressed() {
    FocusScope.of(context).unfocus();

    final isValid = switch (_currentStep) {
      EmailSignUpStep.email => _emailFormKey.currentState?.validate() ?? false,
      EmailSignUpStep.name => _nameFormKey.currentState?.validate() ?? false,
      EmailSignUpStep.password => false,
    };

    if (!isValid) return;

    setState(() {
      _currentStep = switch (_currentStep) {
        EmailSignUpStep.email => EmailSignUpStep.name,
        EmailSignUpStep.name => EmailSignUpStep.password,
        EmailSignUpStep.password => EmailSignUpStep.password,
      };
    });
  }

  void _onSignUpPressed() {
    FocusScope.of(context).unfocus();
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

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
              current is EmailOtpSentState,
          listener: (context, state) {
            if (!_isSubmitting) return;

            if (state is AuthFailure) {
              setState(() => _isSubmitting = false);
              final message = state.messageKey != null
                  ? localizeAuthMessage(l10n, state.messageKey!)
                  : state.message;
              PopupDialogs.showErrorDialog(context, message);
            } else if (state is AuthSuccess) {
              setState(() => _isSubmitting = false);
              navigateAfterSignUp(context, user: state.user);
            } else if (state is EmailOtpSentState) {
              setState(() => _isSubmitting = false);
              context.pushNamed(
                'email_otp_verify',
                queryParameters: {'email': state.email},
              );
            }
          },
          builder: (context, state) {
            return EmailSignUpView(
              l10n: l10n,
              isArabic: isArabic,
              isDark: isDark,
              currentStep: _currentStep,
              emailFormKey: _emailFormKey,
              nameFormKey: _nameFormKey,
              passwordFormKey: _passwordFormKey,
              fullNameController: fullNameController,
              emailController: emailController,
              passwordController: passwordController,
              isLoading: _isSubmitting || state is AuthLoading,
              onBackPressed: _onBackPressed,
              onNextPressed: _onNextPressed,
              onSignUpPressed: _onSignUpPressed,
            );
          },
        );
      },
    );
  }
}
