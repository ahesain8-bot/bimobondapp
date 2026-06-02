import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

class ChatTypingIndicator extends StatelessWidget {
  const ChatTypingIndicator({
    required this.peerImageUrl,
    required this.username,
    super.key,
  });

  final String peerImageUrl;
  final String username;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: ChatLayoutConstants.typingIndicatorTopPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SafeNetworkAvatar(
            imageUrl: peerImageUrl,
            radius: ChatLayoutConstants.receivedMessageAvatarRadius,
            fallbackText: username,
          ),
          const SizedBox(
            width: ChatLayoutConstants.receivedMessageAvatarGap,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ChatLayoutConstants.typingIndicatorHorizontalPadding,
              vertical: ChatLayoutConstants.typingIndicatorVerticalPadding,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(
                ChatLayoutConstants.typingIndicatorRadius,
              ),
            ),
            child: Text(
              '...',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
