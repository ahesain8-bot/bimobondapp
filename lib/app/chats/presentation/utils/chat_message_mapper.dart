import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/shared_post_snapshot.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_shared_post_cache.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/app/home/presentation/utils/chat_voice_duration_formatter.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
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

String formatInboxTime(DateTime? dateTime, AppLocalizations l10n) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.inboxTimeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.inboxTimeHours(diff.inHours);
  if (diff.inDays < 7) return l10n.inboxTimeDays(diff.inDays);
  return DateFormat.MMMd(l10n.localeName).format(local);
}

Map<String, dynamic>? _sharedStoryUiMap(ChatMessageEntity message) {
  if (message.sharedPost != null) {
    return message.sharedPost!.toUiMap();
  }
  final id = message.sharedPostId?.trim();
  if (id == null || id.isEmpty) return null;
  final cached = ChatSharedPostCache.get(id);
  if (cached != null) {
    return SharedPostSnapshot.fromPost(cached).toUiMap();
  }
  return null;
}

String _typeToUi(ChatMessageType type) {
  switch (type) {
    case ChatMessageType.text:
      return 'text';
    case ChatMessageType.image:
      return 'image';
    case ChatMessageType.video:
      return 'video';
    case ChatMessageType.audio:
      return 'voice';
    case ChatMessageType.location:
      return 'location';
    case ChatMessageType.file:
      return 'file';
    case ChatMessageType.contact:
      return 'contact';
    case ChatMessageType.gift:
      return 'gift';
    case ChatMessageType.poll:
      return 'poll';
    case ChatMessageType.share:
      return 'share';
    case ChatMessageType.unknown:
      return 'text';
  }
}

Map<String, dynamic> chatMessageToUiMap(
  ChatMessageEntity message,
  String currentUserId,
) {
  final isMe = message.senderId == currentUserId;
  final readByMe = message.isReadBy(currentUserId);
  final reactions = <String>[];
  final seenEmojis = <String>{};
  for (final reaction in message.reactions) {
    final emoji = reaction.emoji.trim();
    if (emoji.isNotEmpty && seenEmojis.add(emoji)) {
      reactions.add(emoji);
    }
  }

  Map<String, dynamic>? replyTo;
  if (message.replyPreview != null) {
    replyTo = chatMessageToUiMap(message.replyPreview!, currentUserId);
  }

  final location = ChatLocationPayload.tryParse(
    message.content,
    message.payload,
  );
  final contact = ChatContactPayload.tryParse(message.content, message.payload);
  final file = ChatFilePayload.tryParse(
    message.content,
    message.mediaUrl,
    message.payload,
  );
  final gift = ChatGiftPayload.tryParse(message.payload);

  return {
    'id': message.id,
    'createdAtMs': message.createdAt?.millisecondsSinceEpoch ?? 0,
    'type': message.isDeleted ? 'text' : _typeToUi(message.type),
    'text': message.isDeleted ? '' : (message.content ?? ''),
    if (message.isDeleted) 'textKey': 'deleted',
    'isDeleted': message.isDeleted,
    if (message.payload != null) 'payload': message.payload,
    if (message.type == ChatMessageType.image &&
        message.mediaUrl != null &&
        !message.isDeleted)
      'imageUrl': message.mediaUrl,
    if (message.type == ChatMessageType.video &&
        message.mediaUrl != null &&
        !message.isDeleted)
      'videoUrl': message.mediaUrl,
    if (message.type == ChatMessageType.audio && !message.isDeleted) ...{
      'duration': formatVoiceDurationFromContent(message.content),
      if (message.mediaUrl != null) ...{
        'audioUrl': message.mediaUrl,
        'mediaUrl': message.mediaUrl,
      },
    },
    if (message.type == ChatMessageType.file &&
        file != null &&
        !message.isDeleted) ...{
      'fileName': file.fileName,
      'fileUrl': file.url,
      'mimeType': file.mimeType,
      if (file.sizeBytes != null) 'sizeBytes': file.sizeBytes,
      'fileSizeLabel': formatFileSizeBytes(file.sizeBytes),
    },
    if (message.type == ChatMessageType.location &&
        location != null &&
        !message.isDeleted) ...{
      'locationLabel': location.displayLabel,
      'locationName': location.name,
      'locationAddress': location.address,
      'mapsUrl': location.mapsUrl,
      'latitude': location.latitude,
      'longitude': location.longitude,
    },
    if (message.type == ChatMessageType.contact &&
        contact != null &&
        !message.isDeleted) ...{
      'contactName': contact.name,
      'contactPhone': contact.phone,
      if (contact.email != null) 'contactEmail': contact.email,
      if (contact.userId != null) 'contactUserId': contact.userId,
      if (contact.avatarUrl != null) 'contactAvatarUrl': contact.avatarUrl,
    },
    if (message.type == ChatMessageType.gift &&
        gift != null &&
        !message.isDeleted) ...{
      'giftId': gift.giftId,
      if (gift.name != null) 'giftName': gift.name,
      if (gift.thumbnailUrl != null) 'giftThumbnailUrl': gift.thumbnailUrl,
      if (gift.animationUrl != null) 'giftAnimationUrl': gift.animationUrl,
      if (gift.priceCoins != null) 'giftPriceCoins': gift.priceCoins,
      'giftQuantity': gift.quantity,
    },
    if (message.type == ChatMessageType.poll && !message.isDeleted) ...{
      if (message.poll != null)
        'poll': message.poll!.toUiMap()
      else if (message.payload != null)
        'poll': {
          'question': message.payload!['question']?.toString() ?? '',
          'options': message.payload!['options'] is List
              ? (message.payload!['options'] as List)
                    .map((e) => e.toString())
                    .toList()
              : <String>[],
          'allowMultiple': message.payload!['allowMultiple'] == true,
          'totalVotes': 0,
          'counts': <int>[],
          'votes': <Map<String, dynamic>>[],
          'hasEnded': false,
        },
    },
    'isMe': isMe,
    'time': formatChatMessageTime(message.createdAt),
    'reactions': reactions,
    'status': isMe ? (readByMe ? 'read' : 'sent') : 'read',
    if (replyTo != null) 'replyTo': replyTo,
    if (message.sharedPostId != null && message.sharedPostId!.isNotEmpty)
      'sharedPostId': message.sharedPostId,
    if (_sharedStoryUiMap(message) case final map?) 'sharedStory': map,
    'senderId': message.senderId,
  };
}

int compareChatMessagesByTime(Map<String, dynamic> a, Map<String, dynamic> b) {
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
