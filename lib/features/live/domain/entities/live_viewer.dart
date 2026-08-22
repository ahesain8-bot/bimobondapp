/// One person watching the live, from `GET /lives/:id/viewers`.
class LiveViewer {
  const LiveViewer({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.isVerified = false,
    this.gifterLevel,
    this.isActive = true,
  });

  final String userId;

  /// Real name where the account has one, otherwise the generated handle.
  final String displayName;

  final String? username;
  final String? avatarUrl;
  final bool isVerified;
  final int? gifterLevel;

  /// Still in the room; `false` once the session has a `leftAt`.
  final bool isActive;
}
