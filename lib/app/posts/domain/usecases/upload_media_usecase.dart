import 'dart:io';
import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';

class UploadMediaUseCase implements UseCase<String, File> {
  final PostsRepository repository;

  UploadMediaUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(File file) async {
    return await repository.uploadMedia(file);
  }
}
