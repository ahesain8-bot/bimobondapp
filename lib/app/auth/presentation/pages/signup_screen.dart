import 'package:bimobondapp/app/auth/data/datasources/auth_local_data_source.dart';
import 'package:bimobondapp/core/widgets/custom_app_bar.dart';
import 'package:bimobondapp/core/widgets/language_toggle_button.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/app/auth/presentation/pages/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/custom_text_field.dart';
import 'package:bimobondapp/core/widgets/password_text_field.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:bimobondapp/core/widgets/social_icon_button.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SignUpScreen extends StatefulWidget {
  final String language;

  const SignUpScreen({super.key, required this.language});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        final currentLanguage = locale.languageCode;
        final isArabic = currentLanguage == 'ar';
        final textDirection = isArabic ? TextDirection.rtl : TextDirection.ltr;
        final l10n = AppLocalizations.of(context)!;

        return Directionality(
          textDirection: textDirection,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 100,
              leading: TextButton.icon(
                onPressed: () => context.pop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
                label: CustomText(
                  l10n.back,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ),
            body: BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) =>
                  current is AuthFailure ||
                  current is AuthSuccess ||
                  current is EmailVerificationSentState ||
                  current is EmailOtpSentState,
              listener: (context, state) {
                if (!_isSubmitting) return;

                if (state is AuthFailure) {
                  _isSubmitting = false;
                  String message = state.messageKey != null
                      ? _getLocalizedMessage(l10n, state.messageKey!)
                      : state.message;
                  PopupDialogs.showErrorDialog(context, message);
                } else if (state is EmailVerificationSentState) {
                  _isSubmitting = false;
                  context.pushReplacementNamed(
                    'email_verification',
                    queryParameters: {'email': state.email},
                  );
                } else if (state is AuthSuccess) {
                  _isSubmitting = false;
                  // Fallback success state if email verification is not required
                  context.pushReplacementNamed('home');
                } else if (state is EmailOtpSentState) {
                  _isSubmitting = false;
                  context.pushNamed(
                    'email_otp_verify',
                    queryParameters: {'email': state.email},
                  );
                }
              },
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p24,
                    vertical: AppSizes.p16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomText(
                                    l10n.signUpTitle,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  const SizedBox(height: AppSizes.p4),
                                  CustomText(
                                    l10n.signUpSubtitle,
                                    variant: TextVariant.secondary,
                                    fontSize: 14,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSizes.p12),
                            Image.asset(
                              'assets/images/logo.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p32),
                        CustomTextField(
                          controller: emailController,
                          hintText: l10n.emailLabel,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.emailRequired;
                            }
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return l10n.invalidEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),
                        PasswordTextField(
                          controller: passwordController,
                          hintText: l10n.passwordLabel,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.passwordRequired;
                            }
                            if (value.length < 6) {
                              return l10n.passwordTooShort;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusLg,
                                    ),
                                  ),
                                ),
                                onPressed: state is AuthLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          setState(() {
                                            _isSubmitting = true;
                                          });
                                          context.read<AuthBloc>().add(
                                            SignUpWithEmailEvent(
                                              email: emailController.text
                                                  .trim(),
                                              password: passwordController.text
                                                  .trim(),
                                            ),
                                          );
                                        }
                                      },
                                child: state is AuthLoading
                                    ? const CustomLoadingWidget(size: 40)
                                    : CustomText(
                                        l10n.continueAction,
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomText(
                              l10n.alreadyHaveAccount,
                              variant: TextVariant.secondary,
                              fontSize: 15,
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: CustomText(
                                l10n.loginTitle,
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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
