import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bimobondapp/app/auth/domain/usecases/forgot_password_usecase.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/forgot_password/forgot_password_view.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitPressed() async {
    final l10n = AppLocalizations.of(context)!;

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final result = await sl<ForgotPasswordUseCase>()(
      ForgotPasswordParams(email: _emailController.text.trim()),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        final message = failure.message.toLowerCase().contains('not found')
            ? l10n.forgotPasswordUserNotFound
            : (failure.message.isNotEmpty
                  ? failure.message
                  : l10n.forgotPasswordFailed);
        PopupDialogs.showErrorDialog(context, message);
      },
      (_) {
        PopupDialogs.showSuccessDialog(context, l10n.forgotPasswordSuccess);
        context.pop();
      },
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final l10n = AppLocalizations.of(context)!;
        final isArabic = locale.languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ForgotPasswordView(
          formKey: _formKey,
          l10n: l10n,
          isArabic: isArabic,
          isDark: isDark,
          emailController: _emailController,
          isLoading: _isSubmitting,
          onSubmitPressed: _onSubmitPressed,
        );
      },
    );
  }
}
