import 'package:bimobondapp/app/home/presentation/utils/chat_attachment_payload.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_attachment_messages.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_image_preview.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_sheets.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_message.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_shared_preview.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class ChatMessageItem extends StatelessWidget {
  const ChatMessageItem({
    required this.msg,
    required this.username,
    required this.peerImageUrl,
    this.peerUserId,
    required this.isFirstInGroup,
    this.isFirstInList = false,
    required this.messageText,
    required this.replyText,
    required this.onLongPress,
    required this.onSwipeReply,
    required this.isRtl,
    super.key,
  });

  final Map<String, dynamic> msg;
  final String username;
  final String peerImageUrl;
  final String? peerUserId;
  final bool isFirstInGroup;
  final bool isFirstInList;
  final String messageText;
  final String? replyText;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = msg['isMe'] as bool? ?? false;
    final isDeleted = msg['isDeleted'] == true;
    final reactions = msg['reactions'] as List? ?? [];
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth * ChatLayoutConstants.messageMaxWidthFactor -
        (isMe ? 0 : ChatLayoutConstants.receivedMessageAvatarRowWidth);

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

    final contentInset = isMe
        ? 0.0
        : ChatLayoutConstants.receivedMessageAvatarRowWidth;

    final messageColumn = Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (isFirstInGroup && !isMe)
          Padding(
            padding: EdgeInsetsDirectional.only(
              start: contentInset,
              bottom: AppSizes.p4,
            ),
            child: InkWell(
              onTap: () {
                final id = peerUserId?.trim() ?? '';
                if (id.isNotEmpty) {
                  openUserStoryOrProfile(
                    context,
                    userId: id,
                    username: username,
                    avatarUrl: peerImageUrl,
                  );
                  return;
                }
                ChatSheets.showUserInfo(
                  context: context,
                  username: username,
                  imageUrl: peerImageUrl,
                  userId: peerUserId,
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Text(
                  username,
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
          ),
        if (isMe)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: displayBubble,
          )
        else
          Row(
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
                  alignment: AlignmentDirectional.centerStart,
                  child: displayBubble,
                ),
              ),
            ],
          ),
        Padding(
          padding: EdgeInsetsDirectional.only(start: contentInset),
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
  });

  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isFirstInGroup;
  final String messageText;
  final String? replyText;
  final double maxWidth;

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

    final padding = type == 'text'
        ? const EdgeInsets.symmetric(
            horizontal: ChatLayoutConstants.bubbleHorizontalPadding,
            vertical: ChatLayoutConstants.bubbleVerticalPadding,
          )
        : EdgeInsets.zero;

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
            sharedStory:
                sharedStory is Map<String, dynamic> ? sharedStory : null,
            isMe: isMe,
          ),
        ChatMessageContent(
          msg: msg,
          messageText: messageText,
          isMe: isMe,
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
          color: theme.cardColor,
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
        gradient: LinearGradient(
          colors: [
            chatTheme.sentBubbleGradientStart,
            chatTheme.sentBubbleGradientEnd,
          ],
        ),
        borderRadius: borderRadius,
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
        color: (isMe ? chatTheme.bubbleShadow : chatTheme.replyAccent)
            .withValues(alpha: 0.1),
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
            color: isMe ? chatTheme.onSentBubbleMuted : chatTheme.replyAccent,
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
                    : theme.textTheme.bodyMedium?.color?.withValues(
                        alpha: 0.6,
                      ),
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
  });

  final Map<String, dynamic> msg;
  final String messageText;
  final bool isMe;

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
            color: isMe
                ? chatTheme.onSentBubble
                : theme.textTheme.bodyLarge?.color,
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
            borderRadius:
                BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
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
        final location = ChatLocationPayload.tryParse(msg['text']?.toString()) ??
            _locationFromUiMap(msg);
        if (location == null) return const SizedBox.shrink();
        return ChatLocationMessageWidget(payload: location, isMe: isMe);
      case 'file':
        return ChatFileMessageWidget(
          fileName: msg['fileName']?.toString() ??
              msg['text']?.toString() ??
              '',
          fileUrl: msg['fileUrl']?.toString() ?? msg['mediaUrl']?.toString(),
          isMe: isMe,
        );
      case 'contact':
        final contact = ChatContactPayload.tryParse(msg['text']?.toString()) ??
            _contactFromUiMap(msg);
        if (contact == null) return const SizedBox.shrink();
        return ChatContactMessageWidget(payload: contact, isMe: isMe);
      case 'voice':
        return ChatVoiceMessageWidget(
          messageId: msg['id']?.toString() ?? '',
          isMe: isMe,
          duration: msg['duration']?.toString() ?? '0:00',
          audioUrl: msg['audioUrl']?.toString() ?? msg['mediaUrl']?.toString(),
        );
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
      label: msg['locationLabel']?.toString(),
    );
  }

  ChatContactPayload? _contactFromUiMap(Map<String, dynamic> msg) {
    final name = msg['contactName']?.toString();
    final phone = msg['contactPhone']?.toString();
    if (name == null || phone == null) return null;
    return ChatContactPayload(name: name, phone: phone);
  }
}

class ChatMessageFooter extends StatelessWidget {
  const ChatMessageFooter({
    required this.time,
    required this.isMe,
    required this.status,
  });

  final String time;
  final bool isMe;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ChatLayoutConstants.footerHorizontalPadding,
        vertical: ChatLayoutConstants.footerVerticalPadding,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
