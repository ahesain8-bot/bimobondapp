import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/repositories/live_repository.dart';
import '../datasources/live_remote_datasource.dart';
import 'fake_live_repository.dart';

/// Production live repository.
///
/// The existing repository implementation already contains the complete
/// error translation and delegates all feed/join/follow/moderation calls to
/// [LiveRemoteDataSource].  It was historically named `FakeLiveRepository`,
/// which made the production registration misleading.  This adapter gives
/// production a real name and deliberately refuses the two actions for which
/// the documented mobile API has no contract, instead of silently succeeding.
class RealLiveRepository extends LiveRepositoryDelegate {
  RealLiveRepository(super.remote);

  @override
  Future<Either<Failure, void>> reportLive(
    String liveId, {
    required String reason,
    String? details,
  }) async {
    return const Left(
      ServerFailure('Live reporting endpoint is not documented by the API.'),
    );
  }

  @override
  Future<Either<Failure, void>> blockHost(String hostId) async {
    return const Left(
      ServerFailure('Host blocking endpoint is not documented by the API.'),
    );
  }

  @override
  Future<Either<Failure, void>> unblockHost(String hostId) async {
    return const Left(
      ServerFailure('Host unblocking endpoint is not documented by the API.'),
    );
  }
}
