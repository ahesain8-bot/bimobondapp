/// Guest on a live stage (lives/mobile-api.md §10).
class LiveGuest {
  const LiveGuest({
    required this.id,
    required this.liveId,
    required this.userId,
    required this.role,
    required this.status,
    required this.displayName,
    this.avatarUrl,
    this.username,
    this.mutedByHost = false,
    this.cameraOffByHost = false,
  });

  final String id;
  final String liveId;
  final String userId;
  final String role; // GUEST | CO_HOST
  final String status; // REQUESTED | INVITED | ACTIVE | …
  final String displayName;
  final String? avatarUrl;
  final String? username;
  final bool mutedByHost;
  final bool cameraOffByHost;

  bool get isPending => status == 'REQUESTED' || status == 'INVITED';
  bool get isActive => status == 'ACTIVE';
}
