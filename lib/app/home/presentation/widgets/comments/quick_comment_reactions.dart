import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:flutter/material.dart';

class QuickCommentReactions extends StatelessWidget {
  const QuickCommentReactions({required this.onReactionSelected, super.key});

  final ValueChanged<String> onReactionSelected;

  /// Classic TikTok quick-reaction strip (7 emojis).
  static const List<String> emojis = [
    '😁',
    '🥰',
    '😂',
    '😳',
    '😜',
    '😅',
    '🥺',
  ];

  @override
  Widget build(BuildContext context) {
    final size = CommentLayout.composerEmojiSize;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: emojis.map((emoji) {
        return GestureDetector(
          onTap: () => onReactionSelected(emoji),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Text(
              emoji,
              style: TextStyle(fontSize: size, height: 1),
            ),
          ),
        );
      }).toList(),
    );
  }
}
