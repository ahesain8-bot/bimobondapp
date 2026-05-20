import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:flutter/material.dart';

class ChatReplyPreviewBar extends StatelessWidget {
  const ChatReplyPreviewBar({
    required this.text,
    required this.onClose,
    super.key,
  });

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatTheme = ChatTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.p8),
      padding: const EdgeInsets.symmetric(
        horizontal: ChatLayoutConstants.replyBarHorizontalPadding,
        vertical: ChatLayoutConstants.replyBarVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(ChatLayoutConstants.replyBarRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            size: ChatLayoutConstants.replyBarIconSize,
            color: chatTheme.replyAccent,
          ),
          const SizedBox(width: AppSizes.p8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: ChatLayoutConstants.replyBarFontSize,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: ChatLayoutConstants.replyBarIconSize,
              color: theme.iconTheme.color,
            ),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
