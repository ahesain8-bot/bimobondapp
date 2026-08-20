/// A single item in the live-room activity / chat feed.
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.text,
    this.body,
    this.showBadge = false,
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

  /// Whether to show the circular system / level badge beside the message.
  final bool showBadge;

  final String? userId;
  final String? username;
  final int? gifterLevel;
  final bool isPinned;

  LiveChatMessage copyWith({
    String? id,
    String? text,
    String? body,
    bool? showBadge,
    String? userId,
    String? username,
    int? gifterLevel,
    bool? isPinned,
  }) {
    return LiveChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      body: body ?? this.body,
      showBadge: showBadge ?? this.showBadge,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      gifterLevel: gifterLevel ?? this.gifterLevel,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
