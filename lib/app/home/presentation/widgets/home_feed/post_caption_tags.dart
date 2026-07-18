import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_hashtag_chips.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:bimobondapp/core/utils/tag_parser.dart';
import 'package:bimobondapp/core/widgets/tagged_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// TikTok-style post caption with See more / See less.
class PostCaptionTags extends StatefulWidget {
  const PostCaptionTags({required this.post, super.key});

  final PostEntity post;

  @override
  State<PostCaptionTags> createState() => _PostCaptionTagsState();
}

class _PostCaptionTagsState extends State<PostCaptionTags> {
  static const _collapsedMaxLines = 2;

  bool _expanded = false;

  TextStyle get _captionStyle => TextStyle(
    color: Colors.white.withValues(alpha: 0.9),
    fontSize: 14,
    height: 1.4,
    shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
  );

  bool _measureOverflow(double maxWidth, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _captionStyle),
      maxLines: _collapsedMaxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  void didUpdateWidget(covariant PostCaptionTags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.description != widget.post.description) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final post = widget.post;
    final description = post.description!;

    final inTextTags = TagParser.extractHashtagNames(
      description,
    ).map((tag) => tag.toLowerCase()).toSet();
    final extraTags = post.hashtags
        .where((tag) => !inTextTags.contains(tag.toLowerCase()))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final showToggle = _measureOverflow(constraints.maxWidth, description);
        final maxLines = (!_expanded && showToggle) ? _collapsedMaxLines : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: TaggedText(
                text: description,
                style: _captionStyle,
                mentionStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
                hashtagStyle: const TextStyle(
                  color: postCaptionHashtagColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
                post: post,
                mentionUserIds: MentionRefUtils.usernameToUserIdMap(
                  description,
                  post.mentions,
                  post: post,
                ),
                maxLines: maxLines,
                overflow: maxLines != null ? TextOverflow.ellipsis : null,
                onHashtagTap: (name) => openHashtagFeed(context, name),
              ),
            ),
            if (showToggle)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _expanded
                        ? l10n.searchHistorySeeLess
                        : l10n.searchHistorySeeMore,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            if (extraTags.isNotEmpty) ...[
              const SizedBox(height: 6),
              PostHashtagChips(tags: extraTags),
            ],
          ],
        );
      },
    );
  }
}
