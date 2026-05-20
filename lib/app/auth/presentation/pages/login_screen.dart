import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/language_toggle_button.dart';
import 'package:bimobondapp/core/widgets/theme_toggle_button.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/custom_text_field.dart';
import 'package:bimobondapp/core/widgets/password_text_field.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/social_icon_button.dart';
import 'package:bimobondapp/app/auth/presentation/pages/personal_info_screen.dart';
import 'package:bimobondapp/app/auth/presentation/pages/signup_screen.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  bool obscurePassword = true;
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
    if (_formKey.currentState!.validate()) {
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
            body: BlocConsumer<AuthBloc, AuthState>(
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
                  if (_hasLoggedIn) {
                    PopupDialogs.showSuccessDialog(context, l10n.loginSuccess);
                  }
                  context.goNamed('home');
                }
              },
              builder: (context, state) {
                return SafeArea(
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const ThemeToggleButton(),
                              const SizedBox(width: AppSizes.p8),

                              LanguageToggleButton(
                                currentLanguage: currentLanguage,
                                onChanged: (newLang) {
                                  context.read<LocaleCubit>().changeLanguage(
                                    newLang,
                                  );
                                },
                              ),
                            ],
                          ),
                          Center(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(LucideIcons.circleMinus, size: 100),
                            ),
                          ),
                          CustomText(
                            l10n.loginTitle,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                          const SizedBox(height: AppSizes.p6),
                          CustomText(
                            l10n.signInSubtitle,
                            variant: TextVariant.secondary,
                            fontSize: 16,
                          ),
                          const SizedBox(height: AppSizes.p26),
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
                          const SizedBox(height: AppSizes.p24),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: state is AuthLoading
                                  ? null
                                  : _onLoginPressed,
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
                              child: state is AuthLoading
                                  ? const CustomLoadingWidget(size: 40)
                                  : CustomText(
                                      l10n.loginButton,
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Continue with Divider
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.p16,
                                ),
                                child: CustomText(
                                  l10n.continueWith,
                                  variant: TextVariant.secondary,
                                  fontSize: 14,
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),

                          const SizedBox(height: AppSizes.p24),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        context.pushNamed('phone_login'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white24
                                            : Colors.black26,
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSizes.radiusLg,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          AppAssets.mobileIcon,
                                          width: 22,
                                          height: 22,
                                          colorFilter: ColorFilter.mode(
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        CustomText(
                                          l10n.mobileNumberLabel,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSizes.p12),
                              SocialIconButton(
                                icon: SvgPicture.asset(
                                  AppAssets.googleIcon,
                                  width: 24,
                                  height: 24,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSubmitting = true;
                                    _hasLoggedIn = true;
                                  });
                                  context.read<AuthBloc>().add(
                                    const GoogleLoginRequestedEvent(),
                                  );
                                },
                              ),
                              const SizedBox(width: AppSizes.p12),
                              SocialIconButton(
                                icon: const Icon(Icons.apple, size: 28),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p32),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CustomText(
                                l10n.dontHaveAccount,
                                variant: TextVariant.secondary,
                                fontSize: 15,
                              ),
                              GestureDetector(
                                onTap: () => context.pushNamed('signup'),
                                child: CustomText(
                                  l10n.signUp,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p24),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
