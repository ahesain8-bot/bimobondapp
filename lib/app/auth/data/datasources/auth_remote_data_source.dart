import 'package:bimobondapp/core/error/dio_handler.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bimobondapp/app/auth/data/models/user_activity_page_model.dart';
import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/core/network/api_client.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';
import 'package:bimobondapp/core/utils/device_utility.dart';
import 'package:bimobondapp/core/utils/firebase_auth_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({required String name, required String password});
  Future<UserModel> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  });
  Future<UserModel> signInWithFacebook();
  Future<UserModel> signInWithGoogle();
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  });
  Future<UserModel> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  });
  Future<String> uploadAvatar(File file);
  Future<UserModel> updateProfile(Map<String, dynamic> data);
  Future<UserModel> getProfile();
  Future<UserModel> getUserById(String userId);
  Future<UserActivityPageModel> getAdminUserActivity(
    String userId, {
    int page = 1,
    int limit = 10,
  });
  Future<void> syncDeviceRegistration();
  Future<void> forgotPassword({required String email});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;
  AuthRemoteDataSourceImpl({required this.apiClient});

  Future<T> _execute<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  Future<UserModel> _handleFirebaseUserAndBackendLogin(
    UserCredential userCredential,
  ) async {
    if (userCredential.user == null) {
      throw ServerException(message: 'Authentication failed: User is null');
    }

    final idToken = await userCredential.user!.getIdToken(true);
    final deviceInfo = await DeviceUtility.getDeviceInfo();

    print(
      'Calling backend login -> ${ApiConstants.baseUrl}${ApiConstants.backendLogin}',
    );

    final response = await apiClient.dio.post(
      ApiConstants.backendLogin,
      data: deviceInfo,
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = Map<String, dynamic>.from(response.data);
      data['token'] = data['token'] ?? idToken;
      data['deviceToken'] = data['deviceToken'] ?? deviceInfo['deviceId'];
      return UserModel.fromJson(data);
    } else {
      throw ServerException(message: 'Backend authentication failed');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: FirebaseAuthConstants.googleWebClientId,
      );

      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );

      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ServerException(message: 'Google sign-in failed: missing ID token');
      }

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return _handleFirebaseUserAndBackendLogin(userCredential);
    } on GoogleSignInException catch (e) {
      throw ServerException(message: _googleSignInMessage(e));
    } catch (e) {
      throw DioHandler.handle(e);
    }
  }

  @override
  Future<UserModel> signInWithFacebook() => _execute(() async {
    final LoginResult loginResult = await FacebookAuth.instance.login();

    if (loginResult.status == LoginStatus.cancelled) {
      throw ServerException(message: 'Facebook login cancelled');
    }

    if (loginResult.status != LoginStatus.success) {
      throw ServerException(
        message: _facebookLoginMessage(
          loginResult.message ?? 'Facebook login failed',
        ),
      );
    }

    final OAuthCredential credential = FacebookAuthProvider.credential(
      loginResult.accessToken!.tokenString,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    return _handleFirebaseUserAndBackendLogin(userCredential);
  });

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    await FirebaseAuth.instance.setLanguageCode("ar");

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        print('onVerificationCompleted: Automatic verification successful');
        try {
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          if (userCredential.user != null) {
            print(
              'Auto-login successful for: ${userCredential.user!.phoneNumber}',
            );
          }
        } catch (e) {
          throw DioHandler.handle(e);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        print('onVerificationFailed: ${e.code} - ${e.message}');
        verificationFailed(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        print('onCodeSent: $verificationId');
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print('onCodeAutoRetrievalTimeout: $verificationId');
      },
    );
  }

  @override
  Future<UserModel> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) => _execute(() async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await FirebaseAuth.instance.signInWithCredential(
      credential,
    );
    return _handleFirebaseUserAndBackendLogin(userCredential);
  });

  @override
  Future<UserModel> login({required String name, required String password}) =>
      _execute(() async {
        final userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: name, password: password);
        return _handleFirebaseUserAndBackendLogin(userCredential);
      });

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  }) => _execute(() async {
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);

    if (userCredential.user != null) {
      await userCredential.user!.updateDisplayName(fullName);
      await userCredential.user!.sendEmailVerification();
    }
    return _handleFirebaseUserAndBackendLogin(userCredential);
  });

  @override
  Future<String> uploadAvatar(File file) => _execute(() async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await apiClient.dio.post(
      ApiConstants.uploadAvatar,
      data: formData,
      options: Options(
        headers: {
          ...await _profileAuthHeaders(),
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = response.data as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) {
        throw ServerException(message: 'Upload failed: URL is null');
      }
      return url;
    } else {
      throw ServerException(message: 'Upload failed');
    }
  });

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> data) =>
      _execute(() async {
        final response = await apiClient.dio.patch(
          ApiConstants.updateProfile,
          data: data,
          options: Options(headers: await _profileAuthHeaders()),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          return UserModel.fromJson(_parseUserPayload(response.data));
        } else {
          throw ServerException(message: 'Update profile failed');
        }
      });

  Map<String, dynamic> _parseUserPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    throw ServerException(message: 'Invalid profile response');
  }

  Future<Map<String, dynamic>> _profileAuthHeaders() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final idToken = await firebaseUser.getIdToken();
      return {'Authorization': 'Bearer $idToken'};
    }
    return {};
  }

  @override
  Future<UserModel> getProfile() => _execute(() async {
    final response = await apiClient.dio.get(
      ApiConstants.authMe,
      options: Options(headers: await _profileAuthHeaders()),
    );

    if (response.statusCode == 200) {
      return UserModel.fromJson(_parseUserPayload(response.data));
    } else {
      throw ServerException(message: 'Fetch profile failed');
    }
  });

  @override
  Future<UserModel> getUserById(String userId) => _execute(() async {
    final response = await apiClient.dio.get(
      ApiConstants.userById(userId),
      options: Options(headers: await _profileAuthHeaders()),
    );

    if (response.statusCode == 200) {
      return UserModel.fromJson(_parseUserPayload(response.data));
    } else {
      throw ServerException(message: 'Fetch user failed');
    }
  });

  @override
  Future<UserActivityPageModel> getAdminUserActivity(
    String userId, {
    int page = 1,
    int limit = 10,
  }) => _execute(() async {
    final response = await apiClient.dio.get(
      ApiConstants.adminUserActivity(userId),
      queryParameters: {'page': page, 'limit': limit},
      options: Options(headers: await _profileAuthHeaders()),
    );

    if (response.statusCode == 200) {
      return UserActivityPageModel.fromResponse(
        response.data,
        requestedPage: page,
        requestedLimit: limit,
      );
    }
    throw ServerException(message: 'Fetch user activity failed');
  });

  @override
  Future<void> syncDeviceRegistration() => _execute(() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UnauthorizedException(message: 'User not authenticated');
    }

    final idToken = await user.getIdToken(true);
    final deviceInfo = await DeviceUtility.getDeviceInfo();

    await apiClient.dio.post(
      ApiConstants.backendLogin,
      data: deviceInfo,
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );
  });

  @override
  Future<void> forgotPassword({required String email}) => _execute(() async {
    final response = await apiClient.dio.post(
      ApiConstants.forgotPassword,
      data: {'type': 'EMAIL', 'email': email},
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201 ||
        response.statusCode == 204) {
      return;
    }
    throw ServerException(message: 'Forgot password failed');
  });

  String _facebookLoginMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('api access blocked')) {
      return 'Facebook login is blocked for this app. Check Meta Developer Console: app status, tester roles, and Facebook Login settings.';
    }
    return raw;
  }

  String _googleSignInMessage(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in cancelled';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is misconfigured. Add your debug SHA-1 fingerprint to Firebase for com.dubai.bimobondapp, download a new google-services.json, then rebuild.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in UI is unavailable. Try again from the login screen.';
      default:
        final description = error.description?.trim();
        if (description != null && description.isNotEmpty) {
          return description;
        }
        return 'Google sign-in failed';
    }
  }
}
