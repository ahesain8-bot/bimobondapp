import 'dart:io';

import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:dartz/dartz.dart';

class UploadMediaUseCase {
  final PostsRepository repository;

  UploadMediaUseCase(this.repository);

  Future<Either<Failure, String>> call(
    File file, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return repository.uploadMedia(file, onSendProgress: onSendProgress);
  }
}
