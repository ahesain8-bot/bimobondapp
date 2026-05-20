import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_voice_message.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class ChatMessageItem extends StatelessWidget {
  const ChatMessageItem({
    required this.msg,
    required this.username,
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
    final reactions = msg['reactions'] as List? ?? [];

    return Padding(
      padding: EdgeInsets.only(
        top: isFirstInList
            ? ChatLayoutConstants.messageListTopPadding
            : isFirstInGroup
                ? ChatLayoutConstants.messageGroupTopSpacing
                : ChatLayoutConstants.messageItemSpacing,
        bottom: ChatLayoutConstants.messageItemSpacing,
      ),
      child: Column(
        children: [
          if (isFirstInGroup && !isMe)
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSizes.p4,
                left: ChatLayoutConstants.senderHeaderHorizontalPadding,
                right: ChatLayoutConstants.senderHeaderHorizontalPadding,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
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
          Align(
            alignment: isMe
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: GestureDetector(
              onLongPress: onLongPress,
              onHorizontalDragEnd: (details) {
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
                  ),
                  if (reactions.isNotEmpty)
                    Positioned(
                      bottom: ChatLayoutConstants.reactionBadgeBottomOffset,
                      right: isMe ? null : 0,
                      left: isMe ? 0 : null,
                      child: ChatReactionBadge(
                        emoji: reactions.first.toString(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ChatMessageFooter(
            time: msg['time']?.toString() ?? '',
            isMe: isMe,
            status: msg['status']?.toString() ?? 'sent',
          ),
        ],
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.msg,
    required this.isMe,
    required this.isFirstInGroup,
    required this.messageText,
    required this.replyText,
  });

  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isFirstInGroup;
  final String messageText;
  final String? replyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final type = msg['type']?.toString() ?? 'text';

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width *
            ChatLayoutConstants.messageMaxWidthFactor,
      ),
      padding: type == 'text'
          ? const EdgeInsets.symmetric(
              horizontal: ChatLayoutConstants.bubbleHorizontalPadding,
              vertical: ChatLayoutConstants.bubbleVerticalPadding,
            )
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(
                    alpha: ChatLayoutConstants.sentGradientEndAlpha,
                  ),
                ],
              )
            : null,
        color: isMe ? null : theme.cardColor,
        borderRadius: BorderRadiusDirectional.only(
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
        ),
        boxShadow: [
          BoxShadow(
            color: chatTheme.bubbleShadow,
            blurRadius: ChatLayoutConstants.bubbleShadowBlur,
            offset: ChatLayoutConstants.bubbleShadowOffset,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyText != null && replyText!.isNotEmpty)
            ChatBubbleReplyPreview(text: replyText!, isMe: isMe),
          ChatMessageContent(
            msg: msg,
            messageText: messageText,
            isMe: isMe,
          ),
        ],
      ),
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
          ),
        );
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(ChatLayoutConstants.bubbleRadius),
          child: SafeNetworkImage(
            imageUrl: msg['imageUrl']?.toString(),
            width: ChatLayoutConstants.imageMessageWidth,
            height: ChatLayoutConstants.imageMessageHeight,
            fit: BoxFit.cover,
          ),
        );
      case 'voice':
        return ChatVoiceMessageWidget(
          isMe: isMe,
          duration: msg['duration']?.toString() ?? '0:00',
        );
      default:
        return const SizedBox.shrink();
    }
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
