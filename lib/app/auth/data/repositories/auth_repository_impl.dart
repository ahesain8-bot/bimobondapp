import 'dart:io';

import 'package:bimobondapp/app/auth/data/models/user_model.dart';
import 'package:dartz/dartz.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/error/exceptions.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_activity_page_entity.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';
import 'package:bimobondapp/app/auth/data/datasources/auth_remote_data_source.dart';
import 'package:bimobondapp/app/auth/data/datasources/auth_local_data_source.dart';
import 'package:bimobondapp/core/data/likes_local_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final LikesLocalDataSource likesLocalDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.likesLocalDataSource,
  });

  @override
  Future<Either<Failure, UserEntity>> login({
    required String name,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.login(
        name: name,
        password: password,
      );

      // Save tokens if they exist
      if (userModel.authToken != null || userModel.deviceToken != null) {
        print('--- LOGIN SUCCESS ---');
        print('User ID: ${userModel.id}');
        print('Auth Token: ${userModel.authToken}');

        await localDataSource.saveTokens(
          authToken: userModel.authToken ?? '',
          deviceToken: userModel.deviceToken ?? '',
        );
      }

      await localDataSource.saveUser(userModel);

      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userModel = await remoteDataSource.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save tokens if they exist
      if (userModel.authToken != null || userModel.deviceToken != null) {
        print('--- SIGNUP SUCCESS ---');
        print('User ID: ${userModel.id}');
        print('Auth Token: ${userModel.authToken}');

        await localDataSource.saveTokens(
          authToken: userModel.authToken ?? '',
          deviceToken: userModel.deviceToken ?? '',
        );
      }

      await localDataSource.saveUser(userModel);

      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    await remoteDataSource.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      codeSent: codeSent,
      verificationFailed: verificationFailed,
    );
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final userModel = await remoteDataSource.signInWithPhoneNumber(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      if (userModel.authToken != null || userModel.deviceToken != null) {
        await localDataSource.saveTokens(
          authToken: userModel.authToken ?? '',
          deviceToken: userModel.deviceToken ?? '',
        );
      }

      await localDataSource.saveUser(userModel);

      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithFacebook() async {
    try {
      final userModel = await remoteDataSource.signInWithFacebook();

      if (userModel.authToken != null || userModel.deviceToken != null) {
        await localDataSource.saveTokens(
          authToken: userModel.authToken ?? '',
          deviceToken: userModel.deviceToken ?? '',
        );
      }

      await localDataSource.saveUser(userModel);

      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    try {
      final userModel = await remoteDataSource.signInWithGoogle();

      if (userModel.authToken != null || userModel.deviceToken != null) {
        await localDataSource.saveTokens(
          authToken: userModel.authToken ?? '',
          deviceToken: userModel.deviceToken ?? '',
        );
      }

      await localDataSource.saveUser(userModel);

      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadAvatar(File file) async {
    try {
      final url = await remoteDataSource.uploadAvatar(file);
      return Right(url);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    // if (await networkInfo.isConnected) {
    try {
      final updatedUser = await remoteDataSource.updateProfile(data);
      await localDataSource.saveUser(updatedUser);
      return Right(updatedUser);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
    // } else {
    //   return Left(ServerFailure());
    // }
  }

  @override
  Future<Either<Failure, UserEntity>> getProfile() async {
    try {
      final userModel = await remoteDataSource.getProfile();
      await localDataSource.saveUser(userModel);
      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getUserById(String userId) async {
    try {
      final userModel = await remoteDataSource.getUserById(userId);
      return Right(userModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserActivityPageEntity>> getAdminUserActivity(
    String userId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final pageModel = await remoteDataSource.getAdminUserActivity(
        userId,
        page: page,
        limit: limit,
      );
      return Right(pageModel);
    } on AppException catch (e) {
      return Left(_mapExceptionToFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCachedUser() async {
    try {
      final user = await localDataSource.getUser();
      return Right(user);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<void> logout() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      await likesLocalDataSource.clearForUser(userId);
    }
    await localDataSource.clearAuthData();
    await FirebaseAuth.instance.signOut();
  }

  Failure _mapExceptionToFailure(AppException e) {
    if (e is RequestTimeoutException)
      return TimeoutFailure(e.message ?? 'Timeout');
    if (e is UnauthorizedException)
      return UnauthorizedFailure(e.message ?? 'Unauthorized');
    if (e is NetworkException) return NetworkFailure(e.message ?? 'No network');
    return ServerFailure(e.message ?? 'Server Error');
  }
}
