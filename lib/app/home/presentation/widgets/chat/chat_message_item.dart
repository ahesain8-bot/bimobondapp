import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_attachment_messages.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_image_preview.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_message.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_shared_preview.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_bloc.dart';
import 'package:bimobondapp/app/calls/presentation/bloc/call_event.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChatMessageItem extends StatelessWidget {
  const ChatMessageItem({
    required this.msg,
    required this.username,
    required this.peerImageUrl,
    this.peerUserId,
    required this.currentUserName,
    required this.currentUserImageUrl,
    this.currentUserId,
    required this.isFirstInGroup,
    this.isFirstInList = false,
    required this.messageText,
    required this.replyText,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.isRtl,
    this.onPollVote,
    super.key,
  });

  final Map<String, dynamic> msg;
  final String username;
  final String peerImageUrl;
  final String? peerUserId;
  final String currentUserName;
  final String currentUserImageUrl;
  final String? currentUserId;
  final bool isFirstInGroup;
  final bool isFirstInList;
  final String messageText;
  final String? replyText;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final bool isRtl;
  final void Function(String messageId, int optionIndex)? onPollVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = msg['isMe'] as bool? ?? false;
    final isDeleted = msg['isDeleted'] == true;
    final reactions = msg['reactions'] as List? ?? [];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth =
        screenWidth * ChatLayoutConstants.messageMaxWidthFactor -
        ChatLayoutConstants.receivedMessageAvatarRowWidth;

    final bubble = GestureDetector(
      onLongPress: isDeleted ? null : onLongPress,
      onHorizontalDragEnd: isDeleted
          ? null
          : (details) {
              final velocity = details.primaryVelocity ?? 0;
              if ((isRtl && velocity < 0) || (!isRtl && velocity > 0)) {
                onSwipeReply();
              }
            },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChatMessageBubble(
            msg: msg,
            isMe: isMe,
            isFirstInGroup: isFirstInGroup,
            messageText: messageText,
            replyText: replyText,
            maxWidth: maxBubbleWidth,
            currentUserId: currentUserId,
            onPollVote: onPollVote,
          ),
          if (reactions.isNotEmpty)
            Positioned(
              bottom: ChatLayoutConstants.reactionBadgeBottomOffset,
              right: isMe ? null : 0,
              left: isMe ? 0 : null,
              child: ChatReactionBadge(
                emoji: reactions.map((e) => e.toString()).join(),
              ),
            ),
        ],
      ),
    );

    final footer = ChatMessageFooter(
      time: msg['time']?.toString() ?? '',
      isMe: isMe,
      status: msg['status']?.toString() ?? 'sent',
    );

    final displayBubble = isDeleted
        ? Opacity(
            opacity: ChatLayoutConstants.deletedMessageOpacity,
            child: bubble,
          )
        : bubble;

    final displayFooter = isDeleted
        ? Opacity(
            opacity: ChatLayoutConstants.deletedMessageOpacity,
            child: footer,
          )
        : footer;

    final contentInset = ChatLayoutConstants.receivedMessageAvatarRowWidth;

    final messageColumn = Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (isFirstInGroup && isMe)
          Padding(
            padding: EdgeInsets.only(right: contentInset, bottom: AppSizes.p4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                currentUserName,
                style: TextStyle(
                  fontSize: ChatLayoutConstants.senderHeaderFontSize,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary.withValues(
                    alpha: ChatLayoutConstants.senderHeaderPrimaryAlpha,
                  ),
                ),
              ),
            ),
          ),
        if (isMe)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: displayBubble,
                  ),
                ),
                const SizedBox(
                  width: ChatLayoutConstants.receivedMessageAvatarGap,
                ),
                _SentMessageAvatarSlot(
                  imageUrl: currentUserImageUrl,
                  username: currentUserName,
                  userId: currentUserId,
                  showAvatar: isFirstInGroup,
                ),
              ],
            ),
          )
        else
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ReceivedMessageAvatarSlot(
                  imageUrl: peerImageUrl,
                  username: username,
                  peerUserId: peerUserId,
                  showAvatar: isFirstInGroup,
                ),
                const SizedBox(
                  width: ChatLayoutConstants.receivedMessageAvatarGap,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: displayBubble,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.only(
            left: isMe ? 0 : contentInset,
            right: isMe ? contentInset : 0,
          ),
          child: displayFooter,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInList
            ? ChatLayoutConstants.messageListTopPadding
            : isFirstInGroup
            ? ChatLayoutConstants.messageGroupTopSpacing
            : ChatLayoutConstants.messageItemSpacing,
        bottom: ChatLayoutConstants.messageItemSpacing,
      ),
      child: messageColumn,
    );
  }
}

class _SentMessageAvatarSlot extends StatelessWidget {
  const _SentMessageAvatarSlot({
    required this.imageUrl,
    required this.username,
    this.userId,
    required this.showAvatar,
  });

  final String imageUrl;
  final String username;
  final String? userId;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    const radius = ChatLayoutConstants.receivedMessageAvatarRadius;
    const size = radius * 2;

    if (showAvatar) {
      return StoryProfileAvatar(
        userId: userId,
        imageUrl: imageUrl,
        radius: radius,
        fallbackText: username,
        username: username,
        fullName: username,
      );
    }

    return const SizedBox(width: size, height: size);
  }
}

class _ReceivedMessageAvatarSlot extends StatelessWidget {
  const _ReceivedMessageAvatarSlot({
    required this.imageUrl,
    required this.username,
    this.peerUserId,
    required this.showAvatar,
  });

  final String imageUrl;
  final String username;
  final String? peerUserId;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    const radius = ChatLayoutConstants.receivedMessageAvatarRadius;
    const size = radius * 2;

    if (showAvatar) {
      return StoryProfileAvatar(
        userId: peerUserId,
        imageUrl: imageUrl,
        radius: radius,
        fallbackText: username,
        username: username,
        fullName: username,
      );
    }

    return const SizedBox(width: size, height: size);
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.msg,
    required this.isMe,
    required this.isFirstInGroup,
    required this.messageText,
    required this.replyText,
    required this.maxWidth,
    this.currentUserId,
    this.onPollVote,
  });

  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isFirstInGroup;
  final String messageText;
  final String? replyText;
  final double maxWidth;
  final String? currentUserId;
  final void Function(String messageId, int optionIndex)? onPollVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final type = msg['type']?.toString() ?? 'text';

    final borderRadius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(ChatLayoutConstants.bubbleRadius),
      topEnd: const Radius.circular(ChatLayoutConstants.bubbleRadius),
      bottomStart: Radius.circular(
        isMe
            ? ChatLayoutConstants.bubbleRadius
            : (isFirstInGroup
                  ? ChatLayoutConstants.bubbleTailRadius
                  : ChatLayoutConstants.bubbleRadius),
      ),
      bottomEnd: Radius.circular(
        isMe
            ? (isFirstInGroup
                  ? ChatLayoutConstants.bubbleTailRadius
                  : ChatLayoutConstants.bubbleRadius)
            : ChatLayoutConstants.bubbleRadius,
      ),
    );

    final denseType = type == 'image' || type == 'video' || type == 'voice';
    final padding = denseType
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(
            horizontal: ChatLayoutConstants.bubbleHorizontalPadding,
            vertical: ChatLayoutConstants.bubbleVerticalPadding,
          );

    final sharedPostId = msg['sharedPostId']?.toString();
    final sharedStory = msg['sharedStory'];
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (replyText != null && replyText!.isNotEmpty)
          ChatBubbleReplyPreview(text: replyText!, isMe: isMe),
        if (sharedPostId != null && sharedPostId.isNotEmpty)
          ChatStoryReplyPreview(
            sharedPostId: sharedPostId,
            sharedStory: sharedStory is Map<String, dynamic>
                ? sharedStory
                : null,
            isMe: isMe,
          ),
        ChatMessageContent(
          msg: msg,
          messageText: messageText,
          isMe: isMe,
          currentUserId: currentUserId,
          onPollVote: onPollVote,
        ),
      ],
    );

    final shadow = [
      BoxShadow(
        color: chatTheme.bubbleShadow,
        blurRadius: ChatLayoutConstants.bubbleShadowBlur,
        offset: ChatLayoutConstants.bubbleShadowOffset,
      ),
    ];

    if (!isMe) {
      return Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding,
        decoration: BoxDecoration(
          color: chatTheme.receivedBubbleColor,
          borderRadius: borderRadius,
          boxShadow: shadow,
        ),
        child: content,
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: padding,
      decoration: BoxDecoration(
        color: chatTheme.sentBubbleColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: theme.dividerColor.withValues(
            alpha: ChatLayoutConstants.sentBubbleBorderAlpha,
          ),
        ),
        boxShadow: shadow,
      ),
      child: content,
    );
  }
}

class ChatBubbleReplyPreview extends StatelessWidget {
  const ChatBubbleReplyPreview({required this.text, required this.isMe});

  final String text;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p6),
      padding: const EdgeInsets.all(AppSizes.p8),
      decoration: BoxDecoration(
        color: (isMe ? chatTheme.replyAccent : chatTheme.onReceivedBubbleMuted)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(
          ChatLayoutConstants.replyPreviewRadius,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ChatLayoutConstants.replyPreviewBarWidth,
            height: ChatLayoutConstants.replyPreviewBarHeight,
            color: isMe ? chatTheme.replyAccent : chatTheme.onReceivedBubble,
          ),
          const SizedBox(width: AppSizes.p8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: ChatLayoutConstants.replyPreviewFontSize,
                color: isMe
                    ? chatTheme.onSentBubbleMuted
                    : chatTheme.onReceivedBubbleMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageContent extends StatelessWidget {
  const ChatMessageContent({
    required this.msg,
    required this.messageText,
    required this.isMe,
    this.currentUserId,
    this.onPollVote,
  });

  final Map<String, dynamic> msg;
  final String messageText;
  final bool isMe;
  final String? currentUserId;
  final void Function(String messageId, int optionIndex)? onPollVote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final type = msg['type']?.toString() ?? 'text';
    final isDeleted = msg['isDeleted'] == true;

    switch (type) {
      case 'text':
        return Text(
          messageText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble,
            fontSize: ChatLayoutConstants.messageFontSize,
            height: ChatLayoutConstants.messageLineHeight,
            fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
          ),
        );
      case 'image':
        final imageUrl = msg['imageUrl']?.toString() ?? '';
        final canPreview = !isDeleted && imageUrl.trim().isNotEmpty;
        return GestureDetector(
          onTap: canPreview
              ? () => showChatImagePreview(context, imageUrl: imageUrl)
              : null,
          behavior: HitTestBehavior.opaque,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              ChatLayoutConstants.bubbleRadius,
            ),
            child: SafeNetworkImage(
              imageUrl: imageUrl,
              width: ChatLayoutConstants.imageMessageWidth,
              height: ChatLayoutConstants.imageMessageHeight,
              fit: BoxFit.cover,
            ),
          ),
        );
      case 'video':
        final videoUrl = msg['videoUrl']?.toString();
        if (videoUrl == null || videoUrl.isEmpty) {
          return const SizedBox.shrink();
        }
        return ChatVideoMessageWidget(videoUrl: videoUrl);
      case 'location':
        final location =
            ChatLocationPayload.tryParse(
              msg['text']?.toString(),
              msg['payload'] is Map
                  ? Map<String, dynamic>.from(msg['payload'] as Map)
                  : null,
            ) ??
            _locationFromUiMap(msg);
        if (location == null) return const SizedBox.shrink();
        return ChatLocationMessageWidget(payload: location, isMe: isMe);
      case 'file':
        return ChatFileMessageWidget(
          fileName:
              msg['fileName']?.toString() ?? msg['text']?.toString() ?? '',
          fileUrl: msg['fileUrl']?.toString() ?? msg['mediaUrl']?.toString(),
          sizeLabel: msg['fileSizeLabel']?.toString(),
          isMe: isMe,
        );
      case 'contact':
        final contact =
            ChatContactPayload.tryParse(
              msg['text']?.toString(),
              msg['payload'] is Map
                  ? Map<String, dynamic>.from(msg['payload'] as Map)
                  : null,
            ) ??
            _contactFromUiMap(msg);
        if (contact == null) return const SizedBox.shrink();
        return ChatContactMessageWidget(payload: contact, isMe: isMe);
      case 'gift':
        return ChatGiftMessageWidget(
          isMe: isMe,
          giftName: msg['giftName']?.toString() ?? msg['text']?.toString(),
          thumbnailUrl:
              msg['giftThumbnailUrl']?.toString() ??
              msg['giftAnimationUrl']?.toString(),
          quantity: msg['giftQuantity'] is num
              ? (msg['giftQuantity'] as num).toInt()
              : 1,
        );
      case 'poll':
        final poll = msg['poll'];
        if (poll is! Map) return const SizedBox.shrink();
        return ChatPollMessageWidget(
          messageId: msg['id']?.toString() ?? '',
          poll: Map<String, dynamic>.from(poll),
          isMe: isMe,
          currentUserId: currentUserId,
          onVote: onPollVote,
        );
      case 'share':
        return Text(
          messageText.isNotEmpty ? messageText : 'Shared a post',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMe ? chatTheme.onSentBubble : chatTheme.onReceivedBubble,
            fontSize: ChatLayoutConstants.messageFontSize,
          ),
        );
      case 'voice':
        return ChatVoiceMessageWidget(
          messageId: msg['id']?.toString() ?? '',
          isMe: isMe,
          duration: msg['duration']?.toString() ?? '0:00',
          audioUrl: msg['audioUrl']?.toString() ?? msg['mediaUrl']?.toString(),
        );
      case 'call':
        return ChatCallMessageWidget(msg: msg, isMe: isMe);
      default:
        return const SizedBox.shrink();
    }
  }

  ChatLocationPayload? _locationFromUiMap(Map<String, dynamic> msg) {
    final lat = msg['latitude'];
    final lng = msg['longitude'];
    if (lat is! num || lng is! num) return null;
    return ChatLocationPayload(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      name: msg['locationName']?.toString() ?? msg['locationLabel']?.toString(),
      address: msg['locationAddress']?.toString(),
    );
  }

  ChatContactPayload? _contactFromUiMap(Map<String, dynamic> msg) {
    final name = msg['contactName']?.toString();
    if (name == null || name.isEmpty) return null;
    return ChatContactPayload(
      name: name,
      phone: msg['contactPhone']?.toString() ?? '',
      email: msg['contactEmail']?.toString(),
      userId: msg['contactUserId']?.toString(),
      avatarUrl: msg['contactAvatarUrl']?.toString(),
    );
  }
}

class ChatMessageFooter extends StatelessWidget {
  const ChatMessageFooter({
    required this.time,
    required this.isMe,
    required this.status,
    super.key,
  });

  final String time;
  final bool isMe;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ChatLayoutConstants.footerHorizontalPadding,
          vertical: ChatLayoutConstants.footerVerticalPadding,
        ),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              time,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: ChatLayoutConstants.timeFontSize,
                color: theme.textTheme.bodySmall?.color?.withValues(
                  alpha: ChatLayoutConstants.timeTextAlpha,
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: AppSizes.p4),
              Icon(
                status == 'read' ? Icons.done_all : Icons.check,
                size: ChatLayoutConstants.statusIconSize,
                color: status == 'read'
                    ? chatTheme.readReceipt
                    : chatTheme.pendingReceipt,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatReactionBadge extends StatelessWidget {
  const ChatReactionBadge({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(ChatLayoutConstants.reactionBadgePadding),
      decoration: BoxDecoration(
        color: theme.cardColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.dividerColor.withValues(
            alpha: ChatLayoutConstants.reactionBadgeBorderAlpha,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: chatTheme.bubbleShadow.withValues(
              alpha: ChatLayoutConstants.reactionBadgeShadowAlpha,
            ),
            blurRadius: ChatLayoutConstants.reactionBadgeShadowBlur,
            offset: ChatLayoutConstants.reactionBadgeShadowOffset,
          ),
        ],
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: ChatLayoutConstants.reactionBadgeSize),
      ),
    );
  }
}

class ChatCallMessageWidget extends StatelessWidget {
  const ChatCallMessageWidget({
    super.key,
    required this.msg,
    required this.isMe,
  });

  final Map<String, dynamic> msg;
  final bool isMe;

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chatTheme = ChatTheme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = theme.brightness == Brightness.dark;

    final payload = msg['payload'] is Map
        ? Map<String, dynamic>.from(msg['payload'] as Map)
        : <String, dynamic>{};

    final callType = (msg['callType'] ?? payload['callType'] ?? 'AUDIO')
        .toString()
        .toUpperCase();
    final status = (msg['callStatus'] ?? payload['status'] ?? 'ENDED')
        .toString()
        .toUpperCase();
    final isVideo = callType == 'VIDEO';

    final rawDuration = msg['durationSeconds'] ?? payload['durationSeconds'];
    int? durationSecs;
    if (rawDuration is num) {
      durationSecs = rawDuration.toInt();
    } else if (rawDuration != null) {
      durationSecs = int.tryParse(rawDuration.toString());
    }

    final isMissed = status == 'MISSED' || status == 'REJECTED';
    final isCancelled = status == 'CANCELLED';

    IconData iconData;
    Color iconColor;
    String statusLabel;

    if (isMissed) {
      iconData = LucideIcons.phoneMissed;
      iconColor = colorScheme.error;
      statusLabel = isAr ? 'مكالمة فائتة' : 'Missed call';
    } else if (isCancelled) {
      iconData = isVideo ? LucideIcons.videoOff : LucideIcons.phoneOff;
      iconColor = colorScheme.secondary;
      statusLabel = isAr ? 'مكالمة ملغاة' : 'Cancelled call';
    } else {
      iconData = isVideo ? LucideIcons.video : LucideIcons.phone;
      iconColor = colorScheme.primary;
      final dur = _formatDuration(durationSecs);
      final title = isVideo
          ? (isAr ? 'مكالمة فيديو' : 'Video call')
          : (isAr ? 'مكالمة صوتية' : 'Voice call');
      statusLabel = dur.isNotEmpty ? '$title ($dur)' : title;
    }

    final peerUserId =
        (msg['peerUserId'] ?? msg['senderId'] ?? payload['initiatorId'] ?? '')
            .toString();
    final chatId = (msg['chatId'] ?? payload['chatId'] ?? '').toString();

    final cardBgColor = isMe
        ? (isDark
            ? colorScheme.primaryContainer.withValues(alpha: 0.35)
            : colorScheme.primary.withValues(alpha: 0.10))
        : (isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHigh);

    final titleTextColor = isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    final subTextColor = isMe
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.75)
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? colorScheme.primary.withValues(alpha: 0.25)
              : colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: titleTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isAr ? 'انقر لإعادة الاتصال' : 'Tap to call back',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () {
              context.read<CallBloc>().add(
                    StartCallEvent(
                      chatId: chatId,
                      type: isVideo ? 'VIDEO' : 'AUDIO',
                      inviteeIds: peerUserId.isNotEmpty ? [peerUserId] : null,
                    ),
                  );
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Icon(
                isVideo ? LucideIcons.video : LucideIcons.phone,
                size: 16,
                color: colorScheme.primary,
              ),
            ),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
