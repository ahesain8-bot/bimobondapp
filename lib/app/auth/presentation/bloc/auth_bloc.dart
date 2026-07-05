import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:bimobondapp/app/auth/domain/usecases/login_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_up_with_email_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/verify_phone_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_in_with_phone_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_in_with_facebook_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/sign_in_with_google_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/update_profile_usecase.dart';
import 'package:bimobondapp/app/auth/domain/usecases/get_profile_usecase.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_event.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/core/error/error_message_resolver.dart';
import 'package:bimobondapp/core/error/failures.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final LoginUseCase loginUseCase;
  final SignUpWithEmailUseCase signUpWithEmailUseCase;
  final VerifyPhoneUseCase verifyPhoneUseCase;
  final SignInWithPhoneUseCase signInWithPhoneUseCase;
  final SignInWithFacebookUseCase signInWithFacebookUseCase;
  final SignInWithGoogleUseCase signInWithGoogleUseCase;
  final UpdateProfileUseCase updateProfileUseCase;
  final GetProfileUseCase getProfileUseCase;

  AuthBloc({
    required this.authRepository,
    required this.loginUseCase,
    required this.signUpWithEmailUseCase,
    required this.verifyPhoneUseCase,
    required this.signInWithPhoneUseCase,
    required this.signInWithFacebookUseCase,
    required this.signInWithGoogleUseCase,
    required this.updateProfileUseCase,
    required this.getProfileUseCase,
  }) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginSubmittedEvent>(_onLoginSubmitted);
    on<VerifyPhoneEvent>(_onVerifyPhone);
    on<PhoneCodeSentEvent>(_onPhoneCodeSent);
    on<PhoneAuthFailedEvent>(_onPhoneAuthFailed);
    on<SubmitOtpEvent>(_onSubmitOtp);
    on<FacebookLoginRequestedEvent>(_onFacebookLoginRequested);
    on<GoogleLoginRequestedEvent>(_onGoogleLoginRequested);
    on<UpdateProfileRequestedEvent>(_onUpdateProfileRequested);
    on<FetchProfileEvent>(_onFetchProfile);
    on<LogoutRequestedEvent>(_onLogoutRequested);
    on<SignUpWithEmailEvent>(_onSignUpWithEmail);
  }

  Future<void> _onFetchProfile(
    FetchProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    final cachedUser = state is AuthSuccess
        ? (state as AuthSuccess).user
        : null;

    final result = await getProfileUseCase(NoParams());
    result.fold((failure) {
      if (failure is UnauthorizedFailure || failure.message == 'Not Found') {
        add(const LogoutRequestedEvent());
        return;
      }
      if (cachedUser != null) {
        emit(AuthSuccess(user: cachedUser));
      }
    }, (user) => emit(AuthSuccess(user: user)));
  }

  void _onLogoutRequested(
    LogoutRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    await authRepository.logout();
    emit(AuthInitial());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    final result = await authRepository.getCachedUser();
    result.fold((failure) => emit(AuthInitial()), (user) {
      if (user != null) {
        emit(AuthSuccess(user: user));
        add(const FetchProfileEvent());
      } else {
        emit(AuthInitial());
      }
    });
  }

  Future<void> _onLoginSubmitted(
    LoginSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await loginUseCase(
      LoginParams(name: event.name, password: event.password),
    );
    result.fold(
      (failure) => emit(
        const AuthFailure(
          message: 'Login failed. Please try again.',
          messageKey: 'loginFailed',
        ),
      ),
      (user) => emit(AuthSuccess(user: user)),
    );
  }

  Future<void> _onVerifyPhone(
    VerifyPhoneEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await verifyPhoneUseCase(
        phoneNumber: event.phoneNumber,
        codeSent: (verificationId, resendToken) {
          add(
            PhoneCodeSentEvent(
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        verificationFailed: (e) {
          add(
            PhoneAuthFailedEvent(
              message: e.message ?? 'Verification failed',
              messageKey: 'verificationFailed',
            ),
          );
        },
      );
    } catch (e) {
      emit(AuthFailure(message: ErrorMessageResolver.resolve(e)));
    }
  }

  void _onPhoneCodeSent(PhoneCodeSentEvent event, Emitter<AuthState> emit) {
    emit(
      PhoneCodeSentState(
        verificationId: event.verificationId,
        resendToken: event.resendToken,
      ),
    );
  }

  void _onPhoneAuthFailed(PhoneAuthFailedEvent event, Emitter<AuthState> emit) {
    emit(AuthFailure(message: event.message, messageKey: event.messageKey));
  }

  Future<void> _onSubmitOtp(
    SubmitOtpEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await signInWithPhoneUseCase(
      verificationId: event.verificationId,
      smsCode: event.smsCode,
    );
    result.fold(
      (failure) => emit(
        const AuthFailure(
          message: 'Invalid OTP code',
          messageKey: 'invalidOtpCode',
        ),
      ),
      (user) => emit(AuthSuccess(user: user)),
    );
  }

  Future<void> _onFacebookLoginRequested(
    FacebookLoginRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await signInWithFacebookUseCase();
    result.fold(
      (failure) => emit(AuthFailure(message: failure.message)),
      (user) => emit(AuthSuccess(user: user)),
    );
  }

  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await signInWithGoogleUseCase();
    result.fold(
      (failure) => emit(AuthFailure(message: failure.message)),
      (user) => emit(AuthSuccess(user: user)),
    );
  }

  Future<void> _onUpdateProfileRequested(
    UpdateProfileRequestedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await updateProfileUseCase(event.data);
    result.fold(
      (failure) => emit(
        const AuthFailure(
          message: 'Failed to update profile',
          messageKey: 'updateProfileFailed',
        ),
      ),
      (user) => emit(AuthSuccess(user: user)),
    );
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await signUpWithEmailUseCase(
      SignUpWithEmailParams(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
      ),
    );
    result.fold(
      (failure) => emit(
        const AuthFailure(
          message: 'Signup failed. Please try again.',
          messageKey: 'signupFailed',
        ),
      ),
      (user) => emit(EmailVerificationSentState(email: event.email)),
    );
  }
}
