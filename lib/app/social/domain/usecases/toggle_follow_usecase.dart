import 'package:bimobondapp/app/social/domain/entities/follow_status.dart';
import 'package:bimobondapp/app/social/domain/repositories/social_repository.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

class ToggleFollowUseCase implements UseCase<FollowStatus, ToggleFollowParams> {
  ToggleFollowUseCase(this.repository);

  final SocialRepository repository;

  @override
  Future<Either<Failure, FollowStatus>> call(ToggleFollowParams params) {
    return repository.toggleFollow(params.userId);
  }
}

class ToggleFollowParams extends Equatable {
  const ToggleFollowParams(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}
