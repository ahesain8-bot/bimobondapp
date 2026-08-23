import 'package:dartz/dartz.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/repositories/guest_repository.dart';

/// [GuestRepository] backed by the Nest guest endpoints.
class RealGuestRepository implements GuestRepository {
  RealGuestRepository({required LiveApiClient apiClient}) : _api = apiClient;

  final LiveApiClient _api;

  @override
  Future<Either<Failure, void>> requestSeat(String liveId) async {
    try {
      await _api.post(ApiEndpoints.liveGuestRequest(liveId));
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to request a guest seat: $e'));
    }
  }

  @override
  Future<Either<Failure, GuestStageCredentials>> acceptInvite(
    String liveId,
  ) async {
    try {
      final payload = await _api.post(
        ApiEndpoints.liveGuestAcceptInvite(liveId),
      );
      final inner = payload['data'];
      final source = inner is Map ? Map<String, dynamic>.from(inner) : payload;
      return Right(
        GuestStageCredentials(
          token: source['token']?.toString() ?? '',
          url:
              source['url']?.toString() ??
              source['livekitUrl']?.toString() ??
              '',
          role: source['role']?.toString() ?? 'GUEST',
        ),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to accept the guest invite: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> leaveStage(String liveId) async {
    try {
      await _api.post(ApiEndpoints.liveGuestLeave(liveId));
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to leave the stage: $e'));
    }
  }

  @override
  Future<Either<Failure, List<GuestSummary>>> listGuests(String liveId) async {
    try {
      final payload = await _api.get(ApiEndpoints.liveGuests(liveId));
      final raw = payload['data'];
      if (raw is! List) return const Right([]);
      return Right(
        raw
            .whereType<Map>()
            .map((e) => _guestFromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
      );
    } catch (e) {
      return Left(ServerFailure('Failed to load guests: $e'));
    }
  }

  GuestSummary _guestFromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;
    final fullName = userMap?['fullName']?.toString();
    final handle = userMap?['username']?.toString();
    return GuestSummary(
      userId: userMap?['id']?.toString() ?? json['userId']?.toString() ?? '',
      displayName: (fullName != null && fullName.trim().isNotEmpty)
          ? fullName.trim()
          : (handle ?? 'ضيف'),
      role: json['role']?.toString() ?? 'GUEST',
      status: json['status']?.toString() ?? '',
      avatarUrl:
          userMap?['avatarUrl']?.toString() ??
          userMap?['profilePicture']?.toString(),
      mutedByHost: json['mutedByHost'] == true,
      cameraOffByHost: json['cameraOffByHost'] == true,
    );
  }
}
