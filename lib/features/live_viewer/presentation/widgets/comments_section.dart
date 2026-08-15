import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
        MediaQuery.sizeOf(context).width * TikTokLiveTokens.commentMaxWidthFactor;

    return Align(
      alignment:
          widget.alignTop ? Alignment.topLeft : Alignment.bottomLeft,
      child: SizedBox(
        width: maxW,
        height: widget.height,
        child: ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.transparent,
                Colors.black,
                Colors.black,
              ],
              stops: [
                0.0,
                TikTokLiveTokens.commentFade / widget.height,
                1.0,
              ],
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
              TextSpan(text: comment.username, style: TikTokLiveTokens.joinUser),
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
                const SizedBox(width: 4),
                const Icon(Icons.card_giftcard, color: Colors.white, size: 14),
              ],
            ),
          ),
        ),
      );
    }

    final level = (comment.userId.hashCode.abs() % 50) + 1;
    final isYou = comment.username == 'You';

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
                    _LevelBadge(level: level),
                    const SizedBox(width: 4),
                    if (level > 30) ...[
                      const _MiniBadge(
                        label: 'No.1',
                        color: TikTokLiveTokens.liveRed,
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

class _LevelBadge extends StatelessWidget {
  final int level;

  const _LevelBadge({required this.level});

  Color get _bg {
    if (level >= 40) return const Color(0xFFFFB020);
    if (level >= 20) return const Color(0xFF9B6DFF);
    return const Color(0xFF4A9EFF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bg, Color.lerp(_bg, Colors.white, 0.25)!],
        ),
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond, size: 8, color: Colors.white),
          const SizedBox(width: 1),
          Text(
            '$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
