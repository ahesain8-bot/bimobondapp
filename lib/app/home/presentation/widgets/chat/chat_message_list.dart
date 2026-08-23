import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_message_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_message_text.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_profile_header.dart';
import 'package:bimobondapp/app/home/presentation/widgets/chat/chat_typing_indicator.dart';
import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    required this.scrollController,
    required this.messages,
    required this.isTyping,
    required this.username,
    required this.peerImageUrl,
    this.peerUserId,
    required this.currentUserName,
    required this.currentUserImageUrl,
    this.currentUserId,
    required this.isRtl,
    required this.onReactionPicker,
    required this.onReplyTo,
    this.onPollVote,
    this.onToggleTranslate,
    this.followersCount,
    this.postsCount,
    this.statsText,
    this.mutualText,
    this.onProfileTap,
    super.key,
  });

  final ScrollController scrollController;
  final List<Map<String, dynamic>> messages;
  final bool isTyping;
  final String username;
  final String peerImageUrl;
  final String? peerUserId;
  final String currentUserName;
  final String currentUserImageUrl;
  final String? currentUserId;
  final bool isRtl;
  final void Function(Map<String, dynamic> msg) onReactionPicker;
  final void Function(Map<String, dynamic> msg) onReplyTo;
  final void Function(String messageId, int optionIndex)? onPollVote;
  final void Function(Map<String, dynamic> msg)? onToggleTranslate;
  final int? followersCount;
  final int? postsCount;
  final String? statsText;
  final String? mutualText;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final totalHeaderItems = 1; // Profile Header at top
    final totalCount = totalHeaderItems + messages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        ChatLayoutConstants.messageListHorizontalPadding,
        ChatLayoutConstants.messageListTopPadding,
        ChatLayoutConstants.messageListHorizontalPadding,
        ChatLayoutConstants.messageListBottomPadding,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return ChatProfileHeader(
            username: username,
            imageUrl: peerImageUrl,
            userId: peerUserId,
            followersCount: followersCount,
            postsCount: postsCount,
            statsText: statsText,
            mutualText: mutualText,
            onTap: onProfileTap,
          );
        }

        final msgIndex = index - totalHeaderItems;

        if (isTyping && msgIndex == messages.length) {
          return ChatTypingIndicator(
            peerImageUrl: peerImageUrl,
            username: username,
            peerUserId: peerUserId,
          );
        }

        final msg = messages[msgIndex];
        final prevMsg = msgIndex > 0 ? messages[msgIndex - 1] : null;
        final isFirstInGroup =
            prevMsg == null || prevMsg['isMe'] != msg['isMe'];

        return ChatMessageItem(
          msg: msg,
          username: username,
          peerImageUrl: peerImageUrl,
          peerUserId: peerUserId,
          currentUserName: currentUserName,
          currentUserImageUrl: currentUserImageUrl,
          currentUserId: currentUserId,
          isFirstInGroup: isFirstInGroup,
          isFirstInList: msgIndex == 0,
          messageText: chatMessageText(msg, l10n),
          replyText: msg['replyTo'] != null
              ? chatMessageText(msg['replyTo'] as Map<String, dynamic>, l10n)
              : null,
          onLongPress: () => onReactionPicker(msg),
          onSwipeReply: () => onReplyTo(msg),
          onPollVote: onPollVote,
          onToggleTranslate: onToggleTranslate,
          isRtl: isRtl,
        );
      },
    );
  }
}
