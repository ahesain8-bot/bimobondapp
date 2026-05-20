import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:bimobondapp/app/auth/domain/repositories/auth_repository.dart';

class UploadAvatarUseCase implements UseCase<String, File> {
  final AuthRepository repository;

  UploadAvatarUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(File params) async {
    return await repository.uploadAvatar(params);
  }
}
