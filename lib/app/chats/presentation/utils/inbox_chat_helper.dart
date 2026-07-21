import 'package:bimobondapp/app/chats/domain/entities/chat_entity.dart';
import 'package:bimobondapp/app/chats/domain/entities/chat_message_entity.dart';
import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';

class InboxChatItem {
  const InboxChatItem({
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.preview,
    required this.time,
    required this.unread,
    this.peerUserId,
    this.active = false,
  });

  final String chatId;
  final String name;
  final String? imageUrl;
  final String preview;
  final String time;
  final bool unread;
  final String? peerUserId;
  final bool active;
}

String inboxLastMessagePreview(
  ChatEntity chat,
  String currentUserId,
  AppLocalizations l10n,
) {
  final last = chat.lastMessage;
  if (last == null) {
    return l10n.messagesInboxNoMessagesYet;
  }

  if (last.isDeleted) {
    return l10n.messagesInboxMessageDeleted;
  }

  final isMe = last.senderId.isNotEmpty && last.senderId == currentUserId;
  String body;
  final contentPreview = last.content?.trim() ?? '';

  if (contentPreview.isNotEmpty &&
      last.type != ChatMessageType.image &&
      last.type != ChatMessageType.video &&
      last.type != ChatMessageType.audio &&
      last.type != ChatMessageType.file) {
    body = contentPreview;
  } else {
    switch (last.type) {
      case ChatMessageType.image:
        body = l10n.messagesInboxLastPhoto;
        break;
      case ChatMessageType.video:
        body = l10n.messagesInboxLastVideo;
        break;
      case ChatMessageType.audio:
        body = l10n.messagesInboxLastVoice;
        break;
      case ChatMessageType.location:
        body = contentPreview.isNotEmpty
            ? contentPreview
            : l10n.messagesInboxLastLocation;
        break;
      case ChatMessageType.file:
        body = contentPreview.isNotEmpty
            ? contentPreview
            : l10n.messagesInboxLastFile;
        break;
      case ChatMessageType.contact:
        body = contentPreview.isNotEmpty
            ? contentPreview
            : l10n.messagesInboxLastContact;
        break;
      case ChatMessageType.gift:
        body = contentPreview.isNotEmpty
            ? contentPreview
            : l10n.messagesInboxLastGift;
        break;
      case ChatMessageType.share:
        body = contentPreview.isNotEmpty
            ? contentPreview
            : l10n.messagesInboxLastShare;
        break;
      case ChatMessageType.poll:
        body = contentPreview.isNotEmpty
            ? contentPreview
            : l10n.messagesInboxLastPoll;
        break;
      case ChatMessageType.text:
      case ChatMessageType.unknown:
        body = contentPreview;
        if (body.isEmpty &&
            last.mediaUrl != null &&
            last.mediaUrl!.isNotEmpty) {
          body = l10n.messagesInboxLastPhoto;
        }
        break;
    }
  }

  if (body.isEmpty) {
    body = l10n.messagesInboxNoMessagesYet;
  }

  if (isMe) {
    return '${l10n.messagesInboxYouPrefix}: $body';
  }
  return body;
}

InboxChatItem inboxChatItemFromEntity(
  ChatEntity chat,
  String currentUserId,
  AppLocalizations l10n,
) {
  final other = chat.otherParticipant(currentUserId);
  final last = chat.lastMessage;
  final preview = inboxLastMessagePreview(chat, currentUserId, l10n);

  return InboxChatItem(
    chatId: chat.id,
    name: chat.isGroup
        ? (chat.name ?? l10n.messagesInboxGroupFallback)
        : (other?.displayName ?? l10n.messagesInboxUserFallback),
    imageUrl: other?.avatarUrl,
    preview: preview,
    time: formatInboxTime(last?.createdAt ?? chat.updatedAt, l10n),
    unread: chat.unreadCount > 0,
    peerUserId: chat.isGroup ? null : other?.id,
    active: other?.isActive ?? false,
  );
}

int _chatActivityMillis(ChatEntity chat) {
  final last = chat.lastMessage?.createdAt ?? chat.updatedAt;
  return last?.millisecondsSinceEpoch ?? 0;
}

List<ChatEntity> sortChatsByRecentActivity(List<ChatEntity> chats) {
  final sorted = List<ChatEntity>.from(chats);
  sorted.sort(
    (a, b) => _chatActivityMillis(b).compareTo(_chatActivityMillis(a)),
  );
  return sorted;
}

List<InboxChatItem> filterInboxChats(List<InboxChatItem> items, String query) {
  if (query.isEmpty) return items;
  final q = query.toLowerCase();
  return items
      .where(
        (c) =>
            c.name.toLowerCase().contains(q) ||
            c.preview.toLowerCase().contains(q),
      )
      .toList();
}
