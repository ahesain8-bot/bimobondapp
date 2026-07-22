import 'dart:io';

import 'package:bimobondapp/app/seller_verification/data/datasources/seller_verification_remote_data_source.dart';
import 'package:bimobondapp/app/seller_verification/domain/entities/seller_verification_entities.dart';
import 'package:bimobondapp/app/seller_verification/domain/repositories/seller_verification_repository.dart';
import 'package:bimobondapp/core/error/failure_mapper.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class SellerVerificationRepositoryImpl implements SellerVerificationRepository {
  SellerVerificationRepositoryImpl({required this.remoteDataSource});

  final SellerVerificationRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, SellerVerificationStatusEntity>> getEligibility() async {
    try {
      return Right(await remoteDataSource.getEligibility());
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SellerVerificationStatusEntity>> getMe() async {
    try {
      return Right(await remoteDataSource.getMe());
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDocument(File file) async {
    try {
      return Right(await remoteDataSource.uploadDocument(file));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }

  @override
  Future<Either<Failure, SellerVerificationStatusEntity>> submit(
    SubmitSellerVerificationInput input,
  ) async {
    try {
      return Right(await remoteDataSource.submit(input));
    } catch (e) {
      return Left(FailureMapper.from(e));
    }
  }
}
