import 'live_chat_message.dart';

/// How deep the room keeps its chat backlog. One constant so every append and
/// every merge trims identically — a feed that trims in two places with two
/// limits drops lines nobody can account for.
const int kLiveChatBacklogLimit = 120;

/// Trims [messages] to the newest [kLiveChatBacklogLimit] entries.
List<LiveChatMessage> capLiveChatMessages(List<LiveChatMessage> messages) {
  if (messages.length <= kLiveChatBacklogLimit) return messages;
  return messages.sublist(messages.length - kLiveChatBacklogLimit);
}

/// Folds the HTTP comment history together with whatever the socket already
/// delivered, keeping history order and appending only unseen live lines.
///
/// Enrichment runs a beat after the room goes Ready, so assigning the history
/// straight onto the session used to wipe every comment that arrived in that
/// window — the host saw their own messages and none of the viewers'.
/// Identity is the comment id, so a line present in both is kept once.
List<LiveChatMessage> mergeLiveChatMessages(
  List<LiveChatMessage> history,
  List<LiveChatMessage> live,
) {
  final seen = <String>{};
  final merged = <LiveChatMessage>[];
  for (final message in history) {
    if (seen.add(message.id)) merged.add(message);
  }
  for (final message in live) {
    if (seen.add(message.id)) merged.add(message);
  }
  return capLiveChatMessages(merged);
}
