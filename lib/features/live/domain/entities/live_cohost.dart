import 'package:equatable/equatable.dart';

/// Multi-room co-host (`lives/live-p1-parity.md` §6, `live-p2-parity.md` §2).
///
/// This is two — up to four — live hosts tiling their own rooms, not a guest
/// promoted to CO_HOST inside one room. Each partner room is joined as a
/// separate, subscribe-only LiveKit connection with the token the server sent.

/// Documented lifecycle: `INVITED` → `ACTIVE` | `DECLINED` | `ENDED`.
enum LiveCohostStatus {
  invited('INVITED'),
  active('ACTIVE'),
  declined('DECLINED'),
  ended('ENDED'),
  unknown('UNKNOWN');

  const LiveCohostStatus(this.wireValue);
  final String wireValue;

  static LiveCohostStatus parse(String? value) {
    final upper = value?.trim().toUpperCase();
    for (final status in values) {
      if (status != unknown && status.wireValue == upper) return status;
    }
    return unknown;
  }
}

/// One co-host session between this room and a partner room.
class LiveCohostSession extends Equatable {
  const LiveCohostSession({
    required this.id,
    required this.status,
    this.hostLiveId,
    this.guestLiveId,
    this.hostUserId,
    this.guestUserId,
    this.guestName,
    this.guestAvatarUrl,
  });

  final String id;
  final LiveCohostStatus status;
  final String? hostLiveId;
  final String? guestLiveId;
  final String? hostUserId;
  final String? guestUserId;
  final String? guestName;
  final String? guestAvatarUrl;

  bool get isActive => status == LiveCohostStatus.active;
  bool get isPending => status == LiveCohostStatus.invited;

  /// The partner of [liveId] in this session, when it is one of the two rooms.
  String? partnerOf(String liveId) {
    if (liveId.isEmpty) return null;
    if (liveId == hostLiveId) return guestLiveId;
    if (liveId == guestLiveId) return hostLiveId;
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    status,
    hostLiveId,
    guestLiveId,
    hostUserId,
    guestUserId,
    guestName,
    guestAvatarUrl,
  ];
}

/// A partner room this client should tile, from `cohosts[]` on join/start.
///
/// The token is always the server's subscribe-only token for that room. The
/// app never reuses its own publish token to render a partner.
class LiveCohostRoom extends Equatable {
  const LiveCohostRoom({
    required this.liveId,
    required this.token,
    required this.url,
    this.roomName,
    this.role,
    this.hostId,
    this.hostName,
    this.hostAvatarUrl,
  });

  final String liveId;
  final String token;
  final String url;
  final String? roomName;

  /// Documented as `viewer` for these tiles — subscribe only.
  final String? role;
  final String? hostId;
  final String? hostName;
  final String? hostAvatarUrl;

  bool get isConnectable =>
      liveId.isNotEmpty && token.isNotEmpty && url.isNotEmpty;

  @override
  List<Object?> get props => [
    liveId,
    token,
    url,
    roomName,
    role,
    hostId,
    hostName,
    hostAvatarUrl,
  ];
}

/// Everything the join/start payload said about co-hosting.
class LiveCohostPayload extends Equatable {
  const LiveCohostPayload({this.rooms = const []});

  /// `cohosts[]`, with the legacy single `cohost` folded in first so older
  /// payloads still tile one partner.
  final List<LiveCohostRoom> rooms;

  bool get isEmpty => rooms.isEmpty;

  static const LiveCohostPayload none = LiveCohostPayload();

  @override
  List<Object?> get props => [rooms];
}
