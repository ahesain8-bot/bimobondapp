import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/widgets/gifter_level_badge.dart';
import '../../domain/entities/comment_entity.dart';
import 'fallback_media.dart';
import 'tiktok_live_tokens.dart';

/// TikTok LIVE comment feed — pixel-matched proportions.
class CommentsSection extends StatefulWidget {
  final List<CommentEntity> comments;
  final double height;

  /// When true, comments sit at the top of the feed (multi-grid under tiles).
  final bool alignTop;

  const CommentsSection({
    super.key,
    required this.comments,
    this.height = TikTokLiveTokens.commentFeedH,
    this.alignTop = false,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  final ScrollController _scrollController = ScrollController();
  int _lastCount = 0;

  @override
  void didUpdateWidget(covariant CommentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.comments.length != _lastCount) {
      _lastCount = widget.comments.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.comments.length > 30
        ? widget.comments.sublist(widget.comments.length - 30)
        : widget.comments;
    final maxW =
        MediaQuery.sizeOf(context).width *
        TikTokLiveTokens.commentMaxWidthFactor;

    return Align(
      alignment: widget.alignTop ? Alignment.topLeft : Alignment.bottomLeft,
      child: SizedBox(
        width: maxW,
        height: widget.height,
        child: ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Colors.transparent, Colors.black, Colors.black],
              stops: [0.0, TikTokLiveTokens.commentFade / widget.height, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final comment = visible[index];
              return TikTokCommentBubble(comment: comment)
                  .animate(key: ValueKey(comment.id))
                  .fadeIn(duration: 140.ms)
                  .slideY(begin: 0.12, end: 0, duration: 180.ms);
            },
          ),
        ),
      ),
    );
  }
}

class TikTokCommentBubble extends StatelessWidget {
  final CommentEntity comment;

  const TikTokCommentBubble({super.key, required this.comment});

  bool get _isJoin => comment.metadata?['type'] == 'join';
  bool get _isGift => comment.metadata?['type'] == 'gift';

  @override
  Widget build(BuildContext context) {
    if (_isJoin) {
      return Padding(
        padding: const EdgeInsets.only(bottom: TikTokLiveTokens.commentGap),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: comment.username,
                style: TikTokLiveTokens.joinUser,
              ),
              TextSpan(
                text: ' joined',
                style: TikTokLiveTokens.commentBody.copyWith(
                  color: const Color(0xD9FFFFFF),
                  shadows: const [],
                ),
              ),
              const TextSpan(text: ' 👋', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_isGift) {
      return Padding(
        padding: const EdgeInsets.only(bottom: TikTokLiveTokens.commentGap),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 30,
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
            decoration: BoxDecoration(
              color: TikTokLiveTokens.frost(0.35),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CachedNetworkImage(
                      imageUrl: comment.userAvatar ?? '',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => FallbackAvatar(
                        seed: comment.userId,
                        name: comment.username,
                        radius: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: comment.username,
                          style: TikTokLiveTokens.commentUser,
                        ),
                        TextSpan(
                          text: ' sent ${comment.content}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((comment.gifterLevel ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  GifterLevelBadge(level: comment.gifterLevel!, compact: true),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.card_giftcard, color: Colors.white, size: 14),
              ],
            ),
          ),
        ),
      );
    }

    final isYou = comment.username == 'You';
    final level = comment.gifterLevel ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: TikTokLiveTokens.commentGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: TikTokLiveTokens.commentAvatar,
              height: TikTokLiveTokens.commentAvatar,
              child: CachedNetworkImage(
                imageUrl: comment.userAvatar ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => FallbackAvatar(
                  seed: comment.userId,
                  name: comment.username,
                  radius: 12,
                ),
                placeholder: (_, __) => FallbackAvatar(
                  seed: comment.userId,
                  name: comment.username,
                  radius: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: TikTokLiveTokens.commentAvatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (level > 0) ...[
                      GifterLevelBadge(level: level, compact: true),
                      const SizedBox(width: 4),
                    ],
                    if (comment.isVerified) ...[
                      const Icon(
                        Icons.verified,
                        size: 12,
                        color: Color(0xFF20D5EC),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (comment.isPinned) ...[
                      const Icon(
                        Icons.push_pin,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        comment.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TikTokLiveTokens.commentUser.copyWith(
                          color: isYou
                              ? TikTokLiveTokens.liveCyan
                              : const Color(0xE6FFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(comment.content, style: TikTokLiveTokens.commentBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating pinned-comment bar from `liveCommentPinned` (mobile-api.md §16).
class PinnedCommentBar extends StatelessWidget {
  final CommentEntity comment;
  final VoidCallback? onClose;

  const PinnedCommentBar({super.key, required this.comment, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: TikTokLiveTokens.frost(0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.push_pin, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          if ((comment.gifterLevel ?? 0) > 0) ...[
            GifterLevelBadge(level: comment.gifterLevel!, compact: true),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${comment.username}: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: comment.content,
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, color: Colors.white54, size: 16),
            ),
        ],
      ),
    );
  }
}
