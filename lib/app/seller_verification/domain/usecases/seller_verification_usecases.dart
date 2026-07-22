import 'dart:io';

import 'package:bimobondapp/app/seller_verification/domain/entities/seller_verification_entities.dart';
import 'package:bimobondapp/app/seller_verification/domain/repositories/seller_verification_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class GetSellerVerificationEligibilityUseCase
    implements UseCase<SellerVerificationStatusEntity, NoParams> {
  GetSellerVerificationEligibilityUseCase(this.repository);

  final SellerVerificationRepository repository;

  @override
  Future<Either<Failure, SellerVerificationStatusEntity>> call(NoParams params) {
    return repository.getEligibility();
  }
}

class GetSellerVerificationMeUseCase
    implements UseCase<SellerVerificationStatusEntity, NoParams> {
  GetSellerVerificationMeUseCase(this.repository);

  final SellerVerificationRepository repository;

  @override
  Future<Either<Failure, SellerVerificationStatusEntity>> call(NoParams params) {
    return repository.getMe();
  }
}

class UploadSellerDocumentUseCase implements UseCase<String, File> {
  UploadSellerDocumentUseCase(this.repository);

  final SellerVerificationRepository repository;

  @override
  Future<Either<Failure, String>> call(File file) {
    return repository.uploadDocument(file);
  }
}

class SubmitSellerVerificationUseCase
    implements
        UseCase<SellerVerificationStatusEntity, SubmitSellerVerificationInput> {
  SubmitSellerVerificationUseCase(this.repository);

  final SellerVerificationRepository repository;

  @override
  Future<Either<Failure, SellerVerificationStatusEntity>> call(
    SubmitSellerVerificationInput params,
  ) {
    return repository.submit(params);
  }
}
