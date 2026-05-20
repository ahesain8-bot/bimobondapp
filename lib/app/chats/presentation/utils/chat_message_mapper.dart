import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:intl/intl.dart';

String formatChatMessageTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final now = DateTime.now();
  if (now.difference(local).inDays == 0) {
    return DateFormat('hh:mm a').format(local);
  }
  if (now.difference(local).inDays < 7) {
    return DateFormat('EEE').format(local);
  }
  return DateFormat('MMM d').format(local);
}

String formatInboxTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('MMM d').format(dateTime);
}

String _typeToUi(ChatMessageType type) {
  switch (type) {
    case ChatMessageType.text:
      return 'text';
    case ChatMessageType.image:
      return 'image';
    case ChatMessageType.video:
      return 'video';
    default:
      return 'text';
  }
}

Map<String, dynamic> chatMessageToUiMap(
  ChatMessageEntity message,
  String currentUserId,
) {
  final isMe = message.senderId == currentUserId;
  final readByMe = message.isReadBy(currentUserId);
  final reactions = message.reactions.map((r) => r.emoji).toList();

  Map<String, dynamic>? replyTo;
  if (message.replyPreview != null) {
    replyTo = chatMessageToUiMap(message.replyPreview!, currentUserId);
  }

  return {
    'id': message.id,
    'createdAtMs': message.createdAt?.millisecondsSinceEpoch ?? 0,
    'type': message.isDeleted ? 'text' : _typeToUi(message.type),
    'text': message.isDeleted
        ? 'This message was deleted'
        : (message.content ?? ''),
    if (message.mediaUrl != null) 'imageUrl': message.mediaUrl,
    'isMe': isMe,
    'time': formatChatMessageTime(message.createdAt),
    'reactions': reactions,
    'status': isMe ? (readByMe ? 'read' : 'sent') : 'read',
    if (replyTo != null) 'replyTo': replyTo,
    'senderId': message.senderId,
  };
}

int compareChatMessagesByTime(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final at = a['createdAtMs'] as int? ?? 0;
  final bt = b['createdAtMs'] as int? ?? 0;
  return at.compareTo(bt);
}

List<Map<String, dynamic>> sortChatMessagesOldestFirst(
  List<Map<String, dynamic>> messages,
) {
  final sorted = List<Map<String, dynamic>>.from(messages);
  sorted.sort(compareChatMessagesByTime);
  return sorted;
}

List<Map<String, dynamic>> chatMessagesToUiMaps(
  List<ChatMessageEntity> messages,
  String currentUserId,
) {
  return sortChatMessagesOldestFirst(
    messages.map((m) => chatMessageToUiMap(m, currentUserId)).toList(),
  );
}
