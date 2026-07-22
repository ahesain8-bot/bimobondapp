import 'package:dartz/dartz.dart';
import 'dart:io';

import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_activity_page_entity.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String name,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  });

  Future<Either<Failure, UserEntity>> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  });

  Future<Either<Failure, UserEntity>> signInWithGoogle();

  Future<Either<Failure, String>> uploadAvatar(File file);
  Future<Either<Failure, UserEntity>> updateProfile(Map<String, dynamic> data);
  Future<Either<Failure, UserEntity>> getProfile();
  Future<Either<Failure, UserEntity>> getUserById(String userId);

  Future<Either<Failure, UserActivityPageEntity>> getAdminUserActivity(
    String userId, {
    int page = 1,
    int limit = 10,
  });

  Future<Either<Failure, UserEntity?>> getCachedUser();

  Future<Either<Failure, void>> forgotPassword({required String email});

  Future<Either<Failure, void>> sendOtp({
    required String type,
    String? email,
    String? phoneNumber,
  });

  Future<Either<Failure, void>> verifyOtp({
    required String type,
    required String code,
    String? email,
    String? phoneNumber,
  });

  Future<Either<Failure, void>> resetPassword({
    required String type,
    required String code,
    required String newPassword,
    String? email,
    String? phoneNumber,
  });

  Future<void> logout();
}
