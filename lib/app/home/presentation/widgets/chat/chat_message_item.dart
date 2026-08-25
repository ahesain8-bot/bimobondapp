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
import 'package:bimobondapp/l10n/app_localizations.dart';
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
    this.onToggleTranslate,
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
  final void Function(Map<String, dynamic> msg)? onToggleTranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isMe = msg['isMe'] as bool? ?? false;
    final isDeleted = msg['isDeleted'] == true;
    final type = msg['type']?.toString() ?? 'text';
    final showTranslation = msg['showTranslation'] == true;
    final isTranslating = msg['isTranslating'] == true;
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
            peerUserId: peerUserId,
            onPollVote: onPollVote,
            onToggleTranslate: onToggleTranslate,
          ),
          if (reactions.isNotEmpty)
            Positioned(
              bottom: ChatLayoutConstants.reactionBadgeBottomOffset,
              right: !isMe ? null : 0,
              left: !isMe ? 0 : null,
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
      crossAxisAlignment: !isMe
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
                  color: theme.colorScheme.secondary,
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
        if (type == 'text' &&
            !isDeleted &&
            messageText.trim().isNotEmpty &&
            onToggleTranslate != null) ...[
          const SizedBox(height: 2),
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : contentInset + 4,
              right: isMe ? contentInset + 4 : 0,
            ),
            child: GestureDetector(
              onTap: isTranslating ? null : () => onToggleTranslate?.call(msg),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTranslating)
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else ...[
                    Icon(
                      LucideIcons.languages,
                      size: 11,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      showTranslation ? l10n.seeOriginal : l10n.seeTranslation,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
    if (!showAvatar) {
      return const SizedBox(
        width: ChatLayoutConstants.receivedMessageAvatarRadius * 2,
      );
    }

    return StoryProfileAvatar(
      userId: userId,
      imageUrl: imageUrl,
      radius: ChatLayoutConstants.receivedMessageAvatarRadius,
      fallbackText: username,
      username: username,
      fullName: username,
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
    if (!showAvatar) {
      return const SizedBox(
        width: ChatLayoutConstants.receivedMessageAvatarRadius * 2,
      );
    }

    return StoryProfileAvatar(
      userId: peerUserId,
      imageUrl: imageUrl,
      radius: ChatLayoutConstants.receivedMessageAvatarRadius,
      fallbackText: username,
      username: username,
      fullName: username,
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
    required this.maxWidth,
    this.currentUserId,
    this.peerUserId,
    this.onPollVote,
    this.onToggleTranslate,
    super.key,
  });

  final Map<String, dynamic> msg;
  final bool isMe;
  final bool isFirstInGroup;
  final String messageText;
  final String? replyText;
  final double maxWidth;
  final String? currentUserId;
  final String? peerUserId;
  final void Function(String messageId, int optionIndex)? onPollVote;
  final void Function(Map<String, dynamic> msg)? onToggleTranslate;

  @override
  Widget build(BuildContext context) {
    final chatTheme = ChatTheme.of(context);
    final type = msg['type']?.toString() ?? 'text';

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
          peerUserId: peerUserId,
          onPollVote: onPollVote,
          onToggleTranslate: onToggleTranslate,
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
          borderRadius: BorderRadius.circular(20),
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isMe ? 0.6 : 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: chatTheme.replyAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
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
    this.peerUserId,
    this.onPollVote,
    this.onToggleTranslate,
    super.key,
  });

  final Map<String, dynamic> msg;
  final String messageText;
  final bool isMe;
  final String? currentUserId;
  final String? peerUserId;
  final void Function(String messageId, int optionIndex)? onPollVote;
  final void Function(Map<String, dynamic> msg)? onToggleTranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final type = msg['type']?.toString() ?? 'text';
    final isDeleted = msg['isDeleted'] == true;

    switch (type) {
      case 'text':
        final translatedText = msg['translatedText']?.toString();
        final showTranslation =
            msg['showTranslation'] == true &&
            translatedText != null &&
            translatedText.trim().isNotEmpty;
        final displayText = showTranslation ? translatedText : messageText;
        final bubbleTextColor = isMe
            ? chatTheme.onSentBubble
            : chatTheme.onReceivedBubble;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bubbleTextColor,
                fontSize: ChatLayoutConstants.messageFontSize,
                height: ChatLayoutConstants.messageLineHeight,
                fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            if (showTranslation) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.languages,
                    size: 11,
                    color: bubbleTextColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    Localizations.localeOf(
                          context,
                        ).languageCode.startsWith('ar')
                        ? 'مترجم'
                        : 'Translated',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: bubbleTextColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
        return ChatCallMessageWidget(
          msg: msg,
          isMe: isMe,
          peerUserId: peerUserId,
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
                status == 'read' ? LucideIcons.checkCheck : LucideIcons.check,
                size: ChatLayoutConstants.statusIconSize,
                color: status == 'read'
                    ? const Color(0xFF34B7F1)
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
  const ChatReactionBadge({required this.emoji, super.key});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class ChatCallMessageWidget extends StatelessWidget {
  const ChatCallMessageWidget({
    required this.msg,
    required this.isMe,
    this.peerUserId,
    super.key,
  });

  final Map<String, dynamic> msg;
  final bool isMe;
  final String? peerUserId;

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    final colorScheme = theme.colorScheme;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final payload = msg['payload'] is Map
        ? Map<String, dynamic>.from(msg['payload'] as Map)
        : <String, dynamic>{};

    final rawCallType =
        (msg['callType'] ??
                payload['callType'] ??
                payload['type'] ??
                msg['mediaType'] ??
                '')
            .toString()
            .toUpperCase();
    final isVideo =
        rawCallType.contains('VIDEO') ||
        msg['isVideo'] == true ||
        payload['isVideo'] == true ||
        payload['type']?.toString().toUpperCase() == 'VIDEO';
    final status = (msg['callStatus'] ?? payload['status'] ?? 'ENDED')
        .toString()
        .toUpperCase();

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
      iconData = isVideo ? LucideIcons.videoOff : LucideIcons.phoneMissed;
      iconColor = colorScheme.error;
      statusLabel = isVideo
          ? (isAr ? 'مكالمة فيديو فائتة' : 'Missed video call')
          : (isAr ? 'مكالمة فائتة' : 'Missed call');
    } else if (isCancelled) {
      iconData = isVideo ? LucideIcons.videoOff : LucideIcons.phoneOff;
      iconColor = colorScheme.secondary;
      statusLabel = isVideo
          ? (isAr ? 'مكالمة فيديو ملغاة' : 'Cancelled video call')
          : (isAr ? 'مكالمة ملغاة' : 'Cancelled call');
    } else {
      iconData = isVideo ? LucideIcons.video : LucideIcons.phone;
      iconColor = colorScheme.secondary;
      final dur = _formatDuration(durationSecs);
      final title = isVideo
          ? (isAr ? 'مكالمة فيديو' : 'Video call')
          : (isAr ? 'مكالمة صوتية' : 'Voice call');
      statusLabel = dur.isNotEmpty ? '$title ($dur)' : title;
    }

    final targetChatId = (msg['chatId'] ?? payload['chatId'] ?? '').toString();

    String targetPeerId = '';
    if (peerUserId != null && peerUserId!.trim().isNotEmpty) {
      targetPeerId = peerUserId!.trim();
    } else {
      final raw =
          msg['peerUserId'] ??
          (isMe ? msg['receiverId'] : msg['senderId']) ??
          payload['initiatorId'] ??
          payload['targetUserId'];
      if (raw != null && raw.toString().trim().isNotEmpty) {
        targetPeerId = raw.toString().trim();
      }
    }

    void handleCallBack() {
      final String callTypeToStart = isVideo ? 'VIDEO' : 'AUDIO';
      context.read<CallBloc>().add(
        StartCallEvent(
          chatId: targetChatId,
          type: callTypeToStart,
          inviteeIds: targetPeerId.isNotEmpty ? [targetPeerId] : null,
        ),
      );
    }

    return InkWell(
      onTap: handleCallBack,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, size: 18, color: iconColor),
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
                      color: isMe
                          ? chatTheme.onSentBubble
                          : chatTheme.onReceivedBubble,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? 'انقر لإعادة الاتصال' : 'Tap to call back',
                    style: TextStyle(
                      color: isMe
                          ? chatTheme.onSentBubbleMuted
                          : chatTheme.onReceivedBubbleMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isVideo ? LucideIcons.video : LucideIcons.phone,
              size: 18,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
