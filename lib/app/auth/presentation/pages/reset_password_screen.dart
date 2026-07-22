import 'package:bimobondapp/app/auth/domain/usecases/forgot_password_usecase.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart';
import 'package:bimobondapp/app/auth/presentation/utils/otp_resend_cooldown.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/phone_login/phone_login_toolbar.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Docs flow C: after forgot-password OTP is sent, user enters OTP + new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.email, super.key});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with OtpResendCooldownMixin {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // OTP was just sent from the forgot-password screen.
    startResendCooldown();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    context.read<AuthBloc>().add(
      ResetPasswordRequestedEvent(
        email: widget.email,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text.trim(),
      ),
    );
  }

  Future<void> _resendCode() async {
    if (!canResendCode) return;

    final l10n = AppLocalizations.of(context)!;
    final result = await sl<ForgotPasswordUseCase>()(
      ForgotPasswordParams(email: widget.email),
    );
    if (!mounted) return;
    result.fold(
      (failure) => PopupDialogs.showErrorDialog(
        context,
        failure.message.isNotEmpty
            ? failure.message
            : l10n.forgotPasswordFailed,
      ),
      (_) {
        startResendCooldown();
        PopupDialogs.showSuccessDialog(context, l10n.forgotPasswordSuccess);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final l10n = AppLocalizations.of(context)!;
        final isArabic = locale.languageCode == 'ar';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
        final theme = Theme.of(context);
        final resendLabel = canResendCode
            ? l10n.resendCode
            : l10n.resendCodeIn(resendSecondsLeft);

        return Directionality(
          textDirection: textDirection,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: BlocListener<AuthBloc, AuthState>(
                listenWhen: (previous, current) =>
                    current is AuthFailure ||
                    current is PasswordResetSuccessState,
                listener: (context, state) {
                  if (state is AuthFailure) {
                    if (_isSubmitting) setState(() => _isSubmitting = false);
                    PopupDialogs.showErrorDialog(context, state.message);
                    return;
                  }
                  if (state is PasswordResetSuccessState) {
                    setState(() => _isSubmitting = false);
                    PopupDialogs.showSuccessDialog(
                      context,
                      l10n.resetPasswordSuccess,
                    );
                    context.goNamed('email_login');
                  }
                },
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p24,
                      vertical: AppSizes.p12,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhoneLoginToolbar(
                            isArabic: isArabic,
                            isDark: isDark,
                          ),
                          const SizedBox(height: AppSizes.p24),
                          CustomText(
                            l10n.resetPasswordTitle,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: AppSizes.p6),
                          CustomText(
                            '${l10n.resetPasswordSubtitle} ${widget.email}',
                            variant: TextVariant.secondary,
                            fontSize: 16,
                          ),
                          const SizedBox(height: AppSizes.p26),
                          LiquidGlassAuthTextField(
                            controller: _codeController,
                            hintText: l10n.verificationCodeLabel,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().length != 6) {
                                return l10n.enterSixDigitCode;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),
                          LiquidGlassAuthPasswordField(
                            controller: _passwordController,
                            hintText: l10n.newPasswordLabel,
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return l10n.passwordTooShort;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),
                          LiquidGlassAuthPasswordField(
                            controller: _confirmController,
                            hintText: l10n.confirmPasswordLabel,
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return l10n.passwordsDoNotMatch;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p24),
                          LiquidGlassAuthPrimaryButton(
                            onPressed: _isSubmitting ? null : _onSubmit,
                            enabled: !_isSubmitting,
                            child: _isSubmitting
                                ? const CustomLoadingWidget(size: 40)
                                : CustomText(
                                    l10n.resetPasswordButton,
                                    color: Colors.white,
                                    fontSize: AppSizes.authControlFontSize,
                                    fontWeight: FontWeight.bold,
                                  ),
                          ),
                          const SizedBox(height: AppSizes.p16),
                          Center(
                            child: TextButton(
                              onPressed: canResendCode ? _resendCode : null,
                              child: CustomText(
                                resendLabel,
                                color: canResendCode
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.45,
                                      ),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
