import 'package:dartz/dartz.dart';
import 'dart:io';

import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String name,
    required String password,
  });

  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
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

  Future<Either<Failure, UserEntity>> signInWithFacebook();

  Future<Either<Failure, UserEntity>> signInWithGoogle();

  Future<Either<Failure, String>> uploadAvatar(File file);
  Future<Either<Failure, UserEntity>> updateProfile(Map<String, dynamic> data);
  Future<Either<Failure, UserEntity>> getProfile();

  Future<Either<Failure, UserEntity?>> getCachedUser();

  Future<void> logout();
}
