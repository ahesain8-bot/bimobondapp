import 'package:dartz/dartz.dart';

import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';

/// LiveKit publish credentials handed out when someone is put on stage
/// (`POST /lives/:id/guests/accept-invite`), per lives/mobile-api.md §10.
class GuestStageCredentials {
  const GuestStageCredentials({
    required this.token,
    required this.url,
    required this.role,
  });

  final String token;
  final String url;
  final String role;

  bool get isUsable => token.isNotEmpty && url.isNotEmpty;
  bool get isCoHost => role.toUpperCase() == 'CO_HOST';
}

/// Someone on, or waiting for, a live's stage.
class GuestSummary {
  const GuestSummary({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.status,
    this.avatarUrl,
    this.mutedByHost = false,
    this.cameraOffByHost = false,
  });

  final String userId;
  final String displayName;
  final String role;
  final String status;
  final String? avatarUrl;
  final bool mutedByHost;
  final bool cameraOffByHost;

  bool get isActive => status == 'ACTIVE';
  bool get isPending => status == 'REQUESTED' || status == 'INVITED';
}

/// Viewer-side multi-guest participation (lives/mobile-api.md §10).
abstract class GuestRepository {
  /// Ask to come on stage (`POST /lives/:id/guests/request`).
  Future<Either<Failure, void>> requestSeat(String liveId);

  /// Accept an invite addressed to you (`POST …/guests/accept-invite`).
  Future<Either<Failure, GuestStageCredentials>> acceptInvite(String liveId);

  /// Step off the stage (`POST /lives/:id/guests/leave`).
  Future<Either<Failure, void>> leaveStage(String liveId);

  /// Current roster (`GET /lives/:id/guests`).
  Future<Either<Failure, List<GuestSummary>>> listGuests(String liveId);
}
