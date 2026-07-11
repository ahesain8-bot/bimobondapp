import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/utils/auth_message_localizer.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/login/google_login_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/signup/signup_view.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/presentation/utils/post_signup_navigation.dart';

class SignUpScreen extends StatefulWidget {
  final String language;

  const SignUpScreen({super.key, required this.language});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _isSubmitting = false;

  Future<void> _onGooglePressed() async {
    final proceed = await GoogleLoginSheet.show(context);
    if (!proceed || !mounted) return;

    setState(() => _isSubmitting = true);
    context.read<AuthBloc>().add(const GoogleLoginRequestedEvent());
  }

  Future<void> _onApplePressed() async {
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showErrorDialog(context, l10n.settingsComingSoon);
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
            } else if (state is AuthSuccess) {
              setState(() => _isSubmitting = false);
              navigateAfterSignUp(context);
            }
          },
          builder: (context, state) {
            return SignUpView(
              l10n: l10n,
              isArabic: isArabic,
              isDark: isDark,
              onGooglePressed: _onGooglePressed,
              onApplePressed: _onApplePressed,
            );
          },
        );
      },
    );
  }
}
