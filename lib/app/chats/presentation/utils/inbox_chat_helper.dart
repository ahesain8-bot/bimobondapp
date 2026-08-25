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
    this.isPinned = false,
    this.isMuted = false,
    this.isTyping = false,
    this.isLastFromMe = false,
    this.isLastReadByPeer = false,
  });

  final String chatId;
  final String name;
  final String? imageUrl;
  final String preview;
  final String time;
  final bool unread;
  final String? peerUserId;
  final bool active;
  final bool isPinned;
  final bool isMuted;
  final bool isTyping;
  final bool isLastFromMe;
  final bool isLastReadByPeer;
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
      case ChatMessageType.call:
        final callType =
            last.payload?['callType']?.toString().toUpperCase() ?? 'AUDIO';
        final isVideo = callType == 'VIDEO';
        final status =
            last.payload?['status']?.toString().toUpperCase() ?? '';
        final isAr = l10n.localeName == 'ar';
        if (status == 'MISSED' || status == 'REJECTED') {
          body = isAr ? '📞 مكالمة فائتة' : '📞 Missed call';
        } else if (isVideo) {
          body = isAr ? '📹 مكالمة فيديو' : '📹 Video call';
        } else {
          body = isAr ? '📞 مكالمة صوتية' : '📞 Voice call';
        }
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
  AppLocalizations l10n, {
  bool isTyping = false,
}) {
  final other = chat.otherParticipant(currentUserId);
  final last = chat.lastMessage;
  final isAr = l10n.localeName == 'ar';
  final preview = isTyping
      ? (isAr ? 'يكتب الآن...' : 'Typing...')
      : inboxLastMessagePreview(chat, currentUserId, l10n);

  final isLastFromMe = last != null &&
      last.senderId.isNotEmpty &&
      last.senderId == currentUserId;

  final isReadByMe = (last != null && last.isReadBy(currentUserId)) ||
      (last?.payload != null && last?.payload!['isRead'] == true);

  final isUnread = !isLastFromMe && !isReadByMe && (chat.unreadCount > 0);

  bool isPeerActive = other?.isActive == true || other?.isOnline == true;
  if (!isPeerActive &&
      other?.lastSeenAt != null &&
      other!.lastSeenAt!.trim().isNotEmpty) {
    try {
      final dt = DateTime.parse(other.lastSeenAt!).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 5) {
        isPeerActive = true;
      }
    } catch (_) {}
  }

  final isLastReadByPeer = last != null &&
      (last.readByUserIds.any((id) => id.isNotEmpty && id != currentUserId) ||
          last.payload?['isRead'] == true ||
          last.payload?['read'] == true ||
          last.payload?['is_read'] == true);

  return InboxChatItem(
    chatId: chat.id,
    name: chat.isGroup
        ? (chat.name ?? l10n.messagesInboxGroupFallback)
        : (other?.displayName ?? l10n.messagesInboxUserFallback),
    imageUrl: other?.avatarUrl,
    preview: preview,
    time: formatInboxTime(last?.createdAt ?? chat.updatedAt, l10n),
    unread: isUnread,
    peerUserId: chat.isGroup ? null : other?.id,
    active: isPeerActive,
    isPinned: chat.isPinned,
    isMuted: chat.isMuted,
    isTyping: isTyping,
    isLastFromMe: isLastFromMe,
    isLastReadByPeer: isLastReadByPeer,
  );
}


int _chatActivityMillis(ChatEntity chat) {
  final last = chat.lastMessage?.createdAt ?? chat.updatedAt;
  return last?.millisecondsSinceEpoch ?? 0;
}

List<ChatEntity> sortChatsByRecentActivity(List<ChatEntity> chats) {
  final sorted = List<ChatEntity>.from(chats);
  sorted.sort((a, b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1; // Pinned chats come FIRST!
    }
    return _chatActivityMillis(b).compareTo(_chatActivityMillis(a));
  });
  return sorted;
}

List<InboxChatItem> sortInboxItems(List<InboxChatItem> items) {
  final sorted = List<InboxChatItem>.from(items);
  sorted.sort((a, b) {
    if (a.isPinned != b.isPinned) {
      return a.isPinned ? -1 : 1; // Pinned items come FIRST!
    }
    return 0;
  });
  return sorted;
}

List<InboxChatItem> filterInboxChats(List<InboxChatItem> items, String query) {
  List<InboxChatItem> result = items;
  if (query.isNotEmpty) {
    final q = query.toLowerCase();
    result = items
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.preview.toLowerCase().contains(q),
        )
        .toList();
  }
  return sortInboxItems(result);
}
