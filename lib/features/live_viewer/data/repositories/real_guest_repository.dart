import 'package:dartz/dartz.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../../../core/models/live_media_hints.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../domain/repositories/guest_repository.dart';

/// [GuestRepository] backed by the Nest guest endpoints.
class RealGuestRepository implements GuestRepository {
  RealGuestRepository({required LiveApiClient apiClient}) : _api = apiClient;

  final LiveApiClient _api;

  @override
  Future<Either<Failure, GuestStageCredentials?>> requestSeat(
    String liveId,
  ) async {
    try {
      final payload = await _api.post(ApiEndpoints.liveGuestRequest(liveId));
      final credentials = _credentialsFromPayload(payload);
      return Right(credentials.isUsable ? credentials : null);
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
      return Right(_credentialsFromPayload(payload));
    } catch (e) {
      return Left(ServerFailure('Failed to accept the guest invite: $e'));
    }
  }

  @override
  Future<Either<Failure, GuestStageCredentials>> refreshStageCredentials(
    String liveId,
  ) async {
    try {
      final payload = await _api.post(ApiEndpoints.liveGuestToken(liveId));
      return Right(_credentialsFromPayload(payload));
    } catch (e) {
      return Left(ServerFailure('Failed to refresh guest credentials: $e'));
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

  Future<Either<Failure, void>> _postGuestAction(
    String path,
    String errorLabel,
  ) async {
    try {
      await _api.post(path);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('$errorLabel: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> acceptGuest({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestAccept(liveId, userId),
    'Failed to accept guest',
  );

  @override
  Future<Either<Failure, void>> rejectGuest({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestReject(liveId, userId),
    'Failed to reject guest',
  );

  @override
  Future<Either<Failure, void>> kickGuest({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestKick(liveId, userId),
    'Failed to kick guest',
  );

  @override
  Future<Either<Failure, void>> muteGuest({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestMute(liveId, userId),
    'Failed to mute guest',
  );

  @override
  Future<Either<Failure, void>> unmuteGuest({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestUnmute(liveId, userId),
    'Failed to unmute guest',
  );

  @override
  Future<Either<Failure, void>> setGuestCameraOff({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestCameraOff(liveId, userId),
    'Failed to turn guest camera off',
  );

  @override
  Future<Either<Failure, void>> setGuestCameraOn({
    required String liveId,
    required String userId,
  }) => _postGuestAction(
    ApiEndpoints.liveGuestCameraOn(liveId, userId),
    'Failed to turn guest camera on',
  );

  @override
  Future<Either<Failure, void>> inviteGuest({
    required String liveId,
    required String userId,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.liveGuestInvite(liveId),
        body: {'userId': userId, 'role': 'GUEST'},
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to invite guest: $e'));
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
      seat: json['seat']?.toString(),
    );
  }

  GuestStageCredentials _credentialsFromPayload(Map<String, dynamic> payload) {
    final inner = payload['data'];
    final source = inner is Map ? Map<String, dynamic>.from(inner) : payload;
    return GuestStageCredentials(
      token: source['token']?.toString() ?? '',
      url: source['url']?.toString() ?? source['livekitUrl']?.toString() ?? '',
      role: source['role']?.toString() ?? 'GUEST',
      mediaHints: LiveMediaHints.fromPayload(
        source,
        fallbackRole: source['role']?.toString() ?? 'guest',
      ),
    );
  }
}
