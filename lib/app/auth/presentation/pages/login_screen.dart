import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/google_login_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/login_view.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  final String language;

  const LoginScreen({super.key, this.language = 'ar'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _hasLoggedIn = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _hasLoggedIn = true;
      _isSubmitting = true;
    });
    context.read<AuthBloc>().add(
      LoginSubmittedEvent(
        name: emailController.text.trim(),
        password: passwordController.text.trim(),
      ),
    );
  }

  Future<void> _onGooglePressed() async {
    final proceed = await GoogleLoginSheet.show(context);
    if (!proceed || !mounted) return;

    setState(() {
      _isSubmitting = true;
      _hasLoggedIn = true;
    });
    context.read<AuthBloc>().add(const GoogleLoginRequestedEvent());
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
              current is AuthFailure || current is AuthSuccess,
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
              if (_hasLoggedIn) {
                PopupDialogs.showSuccessDialog(context, l10n.loginSuccess);
              }
              context.goNamed('home');
            }
          },
          builder: (context, state) {
            return LoginView(
              formKey: _formKey,
              l10n: l10n,
              isArabic: isArabic,
              isDark: isDark,
              emailController: emailController,
              passwordController: passwordController,
              isLoading: _isSubmitting || state is AuthLoading,
              onLoginPressed: _onLoginPressed,
              onGooglePressed: _onGooglePressed,
            );
          },
        );
      },
    );
  }
}
