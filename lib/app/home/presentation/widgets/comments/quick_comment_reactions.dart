import 'package:flutter/material.dart';

class QuickCommentReactions extends StatelessWidget {
  const QuickCommentReactions({required this.onReactionSelected, super.key});

  final ValueChanged<String> onReactionSelected;

  static const List<String> emojis = [
    '😄',
    '❤️',
    '🙌',
    '🔥',
    '👏',
    '😢',
    '😍',
    '😮',
  ];

  static const double emojiSize = 26;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: emojis.map((emoji) {
        return GestureDetector(
          onTap: () => onReactionSelected(emoji),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: emojiSize, height: 1.1),
            ),
          ),
        );
      }).toList(),
    );
  }
}
