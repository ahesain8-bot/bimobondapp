import 'package:bimobondapp/core/constants/chat_layout_constants.dart';
import 'package:flutter/material.dart';

class ChatTypingIndicator extends StatelessWidget {
  const ChatTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        top: ChatLayoutConstants.typingIndicatorTopPadding,
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
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
      ),
    );
  }
}
