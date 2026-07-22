import 'dart:io';

import 'package:bimobondapp/app/seller_verification/domain/entities/seller_verification_entities.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

abstract class SellerVerificationRepository {
  Future<Either<Failure, SellerVerificationStatusEntity>> getEligibility();
  Future<Either<Failure, SellerVerificationStatusEntity>> getMe();
  Future<Either<Failure, String>> uploadDocument(File file);
  Future<Either<Failure, SellerVerificationStatusEntity>> submit(
    SubmitSellerVerificationInput input,
  );
}
