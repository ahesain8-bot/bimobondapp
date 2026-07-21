import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:flutter/material.dart';

const postCaptionHashtagColor = Color(0xFF7FDBFF);

/// Tappable hashtag chips shown under a post caption.
class PostHashtagChips extends StatelessWidget {
  const PostHashtagChips({required this.tags, super.key});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          GestureDetector(
            onTap: () => openHashtagFeed(context, tag),
            behavior: HitTestBehavior.opaque,
            child: Text(
              '#$tag',
              style: const TextStyle(
                color: postCaptionHashtagColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: postCaptionHashtagColor,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
      ],
    );
  }
}
