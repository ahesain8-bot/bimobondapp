/// Host profile shown in the live room header.
class LiveHost {
  const LiveHost({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.username,
    this.isVerified = false,
    this.hostHeartCount = 0,
    this.hostLeagueTier,
  });

  final String id;
  final String displayName;

  /// Optional remote avatar; when null the UI uses a local placeholder.
  final String? avatarUrl;

  final String? username;
  final bool isVerified;

  /// Profile heart count from live `user.hostHeartCount` (parity field).
  final int hostHeartCount;

  final String? hostLeagueTier;

  LiveHost copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? username,
    bool? isVerified,
    int? hostHeartCount,
    String? hostLeagueTier,
  }) {
    return LiveHost(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      username: username ?? this.username,
      isVerified: isVerified ?? this.isVerified,
      hostHeartCount: hostHeartCount ?? this.hostHeartCount,
      hostLeagueTier: hostLeagueTier ?? this.hostLeagueTier,
    );
  }
}
