import 'package:bimobondapp/app/posts/domain/repositories/posts_repository.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/core/usecases/usecase.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

/// Registers a view on a post or story via POST /posts/:id/view.
class RecordPostViewUseCase implements UseCase<int, RecordPostViewParams> {
  RecordPostViewUseCase(this.repository);

  final PostsRepository repository;

  @override
  Future<Either<Failure, int>> call(RecordPostViewParams params) {
    return repository.recordPostView(
      params.postId,
      watchedDuration: params.watchedDuration,
      campaignId: params.campaignId,
      trafficSource: params.trafficSource,
    );
  }
}

class RecordPostViewParams extends Equatable {
  const RecordPostViewParams({
    required this.postId,
    this.watchedDuration,
    this.campaignId,
    this.trafficSource = TrafficSource.forYou,
  });

  final String postId;

  /// Optional watch time in seconds.
  final int? watchedDuration;

  /// Required for promoted/ad feed impressions (`promotion.id`).
  final String? campaignId;

  /// See [TrafficSource] — UPPER_SNAKE_CASE discovery surface.
  final String trafficSource;

  @override
  List<Object?> get props => [postId, watchedDuration, campaignId, trafficSource];
}
