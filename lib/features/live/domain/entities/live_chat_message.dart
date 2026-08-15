/// A single item in the live-room activity / chat feed.
class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.text,
    this.showBadge = false,
    this.userId,
    this.username,
    this.gifterLevel,
    this.isPinned = false,
  });

  final String id;
  final String text;

  /// Whether to show the circular system / level badge beside the message.
  final bool showBadge;

  final String? userId;
  final String? username;
  final int? gifterLevel;
  final bool isPinned;

  LiveChatMessage copyWith({
    String? id,
    String? text,
    bool? showBadge,
    String? userId,
    String? username,
    int? gifterLevel,
    bool? isPinned,
  }) {
    return LiveChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      showBadge: showBadge ?? this.showBadge,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      gifterLevel: gifterLevel ?? this.gifterLevel,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
