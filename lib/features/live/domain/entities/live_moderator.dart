/// Assigned live-room moderator (`GET/POST /lives/:id/moderators`).
class LiveModerator {
  const LiveModerator({
    required this.userId,
    this.liveId,
    this.assignedAt,
    this.username,
    this.avatarUrl,
  });

  final String userId;
  final String? liveId;
  final DateTime? assignedAt;
  final String? username;
  final String? avatarUrl;

  factory LiveModerator.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap = user is Map
        ? Map<String, dynamic>.from(user)
        : const <String, dynamic>{};
    final userId =
        json['userId']?.toString() ??
        userMap['id']?.toString() ??
        json['id']?.toString() ??
        '';
    final assignedAtRaw = json['assignedAt']?.toString();
    return LiveModerator(
      userId: userId,
      liveId: json['liveId']?.toString(),
      assignedAt: assignedAtRaw == null || assignedAtRaw.isEmpty
          ? null
          : DateTime.tryParse(assignedAtRaw),
      username:
          userMap['username']?.toString() ??
          userMap['fullName']?.toString() ??
          json['username']?.toString(),
      avatarUrl:
          userMap['avatarUrl']?.toString() ?? json['avatarUrl']?.toString(),
    );
  }

  static List<LiveModerator> listFromPayload(Map<String, dynamic> payload) {
    final data = payload['data'] ?? payload['moderators'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => LiveModerator.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.userId.isNotEmpty)
        .toList(growable: false);
  }
}
