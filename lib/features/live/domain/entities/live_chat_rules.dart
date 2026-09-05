/// Server-backed chat participation rules for a live stream.
class LiveChatRules {
  const LiveChatRules({
    required this.liveId,
    required this.chatMode,
    required this.slowModeSeconds,
    required this.blockedKeywords,
  });

  final String liveId;
  final String chatMode;
  final int slowModeSeconds;
  final List<String> blockedKeywords;
}
