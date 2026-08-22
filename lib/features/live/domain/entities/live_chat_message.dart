/// A single item in the live-room activity / chat feed.
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.text,
    this.body,
    this.avatarUrl,
    this.showBadge = false,
    this.isJoinEvent = false,
    this.userId,
    this.username,
    this.gifterLevel,
    this.isPinned = false,
  });

  final String id;
  final String text;

  /// The comment on its own, without the `username: ` prefix baked into
  /// [text]. Only real viewer comments carry it; join and gift lines are
  /// whole sentences and leave it null so they keep rendering as one run.
  final String? body;

  /// Commenter's picture, shown beside their line the way TikTok does.
  final String? avatarUrl;

  /// Whether to show the circular system / level badge beside the message.
  final bool showBadge;

  /// Someone walked into the room. Carries its own badge, the way TikTok
  /// marks arrivals apart from what people actually say.
  final bool isJoinEvent;

  final String? userId;
  final String? username;
  final int? gifterLevel;
  final bool isPinned;

  LiveChatMessage copyWith({
    String? id,
    String? text,
    String? body,
    String? avatarUrl,
    bool? showBadge,
    bool? isJoinEvent,
    String? userId,
    String? username,
    int? gifterLevel,
    bool? isPinned,
  }) {
    return LiveChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      body: body ?? this.body,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      showBadge: showBadge ?? this.showBadge,
      isJoinEvent: isJoinEvent ?? this.isJoinEvent,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      gifterLevel: gifterLevel ?? this.gifterLevel,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
