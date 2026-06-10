import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/app/social/presentation/services/mention_friends_source.dart';
import 'package:bimobondapp/core/utils/mention_user_resolver.dart';
import 'package:bimobondapp/core/utils/tag_parser.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders plain text with styled, tappable @mentions and #hashtags.
class TaggedText extends StatefulWidget {
  const TaggedText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.hashtagStyle,
    this.maxLines,
    this.overflow,
    this.mentionUserIds = const {},
    this.post,
    this.textAlign,
    this.onHashtagTap,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final TextStyle? hashtagStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String> mentionUserIds;
  final PostEntity? post;
  final TextAlign? textAlign;
  final void Function(String tagName)? onHashtagTap;

  @override
  State<TaggedText> createState() => _TaggedTextState();
}

class _TaggedTextState extends State<TaggedText> {
  final List<TapGestureRecognizer> _recognizers = [];
  Map<String, String> _resolvedIds = const {};

  @override
  void initState() {
    super.initState();
    _resolvedIds = Map<String, String>.from(widget.mentionUserIds);
    _preloadFriendsIds();
  }

  @override
  void didUpdateWidget(covariant TaggedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.mentionUserIds != widget.mentionUserIds ||
        oldWidget.post != widget.post) {
      _resolvedIds = Map<String, String>.from(widget.mentionUserIds);
      _preloadFriendsIds();
    }
  }

  Future<void> _preloadFriendsIds() async {
    final tokens = TagParser.extractMentionUsernames(widget.text);
    if (tokens.isEmpty) return;

    final allResolved = tokens.every(
      (token) => MentionUserIdResolver.lookupInMap(token, _resolvedIds) != null,
    );
    if (allResolved) return;

    await MentionFriendsSource.ensureLoaded();
    if (!mounted) return;

    final enriched = Map<String, String>.from(_resolvedIds);
    for (final token in tokens) {
      final id = MentionUserIdResolver.syncResolve(
        token,
        knownIds: enriched,
        post: widget.post,
      );
      if (id != null && id.isNotEmpty) {
        enriched[token] = id;
        enriched[token.toLowerCase()] = id;
      }
    }

    if (enriched.length != _resolvedIds.length) {
      setState(() => _resolvedIds = enriched);
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  String _resolveHashtagName(String token) {
    final lower = token.toLowerCase();
    for (final tag in widget.post?.hashtags ?? const <String>[]) {
      if (tag.toLowerCase() == lower) return tag;
    }
    return lower;
  }

  void _onHashtagTap(String name) {
    final resolved = _resolveHashtagName(name);
    if (widget.onHashtagTap != null) {
      widget.onHashtagTap!(resolved);
      return;
    }
    openHashtagFeed(context, resolved);
  }

  Future<void> _onMentionTap(String username) async {
    var userId = MentionUserIdResolver.lookupInMap(username, _resolvedIds);
    userId ??= MentionUserIdResolver.syncResolve(
      username,
      knownIds: _resolvedIds,
      post: widget.post,
    );
    userId ??= await MentionUserIdResolver.resolve(
      username,
      knownIds: _resolvedIds,
      post: widget.post,
    );

    if (!mounted || userId == null || userId.isEmpty) return;

    await openUserStoryOrProfile(
      context,
      userId: userId,
      username: username,
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final mentionColor =
        widget.mentionStyle?.color ?? Theme.of(context).colorScheme.primary;
    final hashtagColor =
        widget.hashtagStyle?.color ?? Theme.of(context).colorScheme.secondary;

    final spans = <InlineSpan>[];
    var index = 0;

    void addPlain(String chunk) {
      if (chunk.isEmpty) return;
      spans.add(TextSpan(text: chunk, style: baseStyle));
    }

    final matches = <_TagMatch>[];
    for (final m in TagParser.mentionPattern.allMatches(widget.text)) {
      matches.add(
        _TagMatch(
          start: m.start,
          end: m.end,
          raw: m.group(0)!,
          name: m.group(1)!,
          isMention: true,
        ),
      );
    }
    for (final m in TagParser.hashtagPattern.allMatches(widget.text)) {
      matches.add(
        _TagMatch(
          start: m.start,
          end: m.end,
          raw: m.group(0)!,
          name: m.group(1)!,
          isMention: false,
        ),
      );
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in matches) {
      if (match.start < index) continue;
      addPlain(widget.text.substring(index, match.start));
      if (match.isMention) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _onMentionTap(match.name);
        _recognizers.add(recognizer);

        final mentionBase = widget.mentionStyle ?? baseStyle;
        spans.add(
          TextSpan(
            text: match.raw,
            style: mentionBase.copyWith(
              color: mentionColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: mentionColor.withValues(alpha: 0.85),
            ),
            recognizer: recognizer,
          ),
        );
      } else {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _onHashtagTap(match.name);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: match.raw,
            style: (widget.hashtagStyle ?? baseStyle).copyWith(
              color: hashtagColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: hashtagColor.withValues(alpha: 0.75),
            ),
            recognizer: recognizer,
          ),
        );
      }
      index = match.end;
    }
    addPlain(widget.text.substring(index));

    if (spans.isEmpty) {
      return Text(
        widget.text,
        style: baseStyle,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
        textAlign: widget.textAlign,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      textAlign: widget.textAlign,
    );
  }
}

class _TagMatch {
  const _TagMatch({
    required this.start,
    required this.end,
    required this.raw,
    required this.name,
    required this.isMention,
  });

  final int start;
  final int end;
  final String raw;
  final String name;
  final bool isMention;
}
