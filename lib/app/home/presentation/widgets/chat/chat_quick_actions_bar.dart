import 'package:bimobondapp/core/theme/chat_theme.dart';
import 'package:flutter/material.dart';

class ChatQuickActionsBar extends StatelessWidget {
  const ChatQuickActionsBar({
    super.key,
    required this.onEmojiSelected,
    this.onNudge,
    this.onSharePost,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback? onNudge;
  final VoidCallback? onSharePost;

  @override
  Widget build(BuildContext context) {
    final chatTheme = ChatTheme.of(context);
    final bgFill = chatTheme.inputFill;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...['❤️', '😂', '🔥', '👍', '😍', '🎉', '🙏', '👏'].map(
            (emoji) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPillItem(
                bgFill: bgFill,
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
                onTap: () => onEmojiSelected(emoji),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required Color bgFill,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgFill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: child,
        ),
      ),
    );
  }
}
