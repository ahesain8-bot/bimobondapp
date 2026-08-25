import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/utils/live_feed_fade.dart';
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

  /// PK video can contain bright walls or clothing behind the feed. Give each
  /// message an opaque dark surface so white text never blends into a tile.
  final bool highContrast;

  final String? currentUserId;
  final String? hostId;
  final List<String> moderatorIds;
  final Set<String> mutedUserIds;
  final Set<String> bannedUserIds;

  final void Function(String commentId, String? targetUserId)? onDeleteComment;
  final void Function(String userId, String? username, String? reason)?
  onMuteUser;
  final void Function(String userId, String? username)? onUnmuteUser;
  final void Function(String userId, String? username, String? reason)?
  onBanUser;
  final void Function(String userId, String? username)? onUnbanUser;

  const CommentsSection({
    super.key,
    required this.comments,
    this.height = TikTokLiveTokens.commentFeedH,
    this.alignTop = false,
    this.highContrast = false,
    this.currentUserId,
    this.hostId,
    this.moderatorIds = const [],
    this.mutedUserIds = const {},
    this.bannedUserIds = const {},
    this.onDeleteComment,
    this.onMuteUser,
    this.onUnmuteUser,
    this.onBanUser,
    this.onUnbanUser,
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
          widget.alignTop
              ? _scrollController.position.maxScrollExtent
              : _scrollController.position.minScrollExtent,
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

    // Local override only: Arabic still shapes right-to-left inside each
    // line, but the feed itself hugs the left edge like the host room does
    // rather than following the RTL start edge into the middle of the screen.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: widget.alignTop ? Alignment.topLeft : Alignment.bottomLeft,
        child: SizedBox(
          width: maxW,
          height: widget.height,
          child: ShaderMask(
            // Same rule as the host feed: a band measured in pixels, capped
            // so a short slot cannot have most of it faded away.
            shaderCallback: (rect) =>
                liveFeedFadeShader(rect, scrollableHeight: widget.height),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scrollController,
              reverse: !widget.alignTop,
              padding: EdgeInsets.zero,
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final comment = widget.alignTop
                    ? visible[index]
                    : visible[visible.length - 1 - index];
                final isHostOrMod =
                    (widget.currentUserId != null &&
                        widget.currentUserId == widget.hostId) ||
                    widget.moderatorIds.contains(widget.currentUserId);
                final isSelf = comment.userId == widget.currentUserId;
                final cIsJoin = comment.metadata?['type'] == 'join';
                final cIsGift = comment.metadata?['type'] == 'gift';
                final isMuted = widget.mutedUserIds.contains(comment.userId);
                final isBanned = widget.bannedUserIds.contains(comment.userId);
                return TikTokCommentBubble(
                      comment: comment,
                      highContrast: widget.highContrast,
                      showModerationMenu:
                          isHostOrMod && !isSelf && !cIsJoin && !cIsGift,
                      isMuted: isMuted,
                      isBanned: isBanned,
                      onDelete: widget.onDeleteComment == null
                          ? null
                          : () => widget.onDeleteComment!(
                              comment.id,
                              comment.userId,
                            ),
                      onMute: widget.onMuteUser == null
                          ? null
                          : () => widget.onMuteUser!(
                              comment.userId,
                              comment.username,
                              null,
                            ),
                      onUnmute: widget.onUnmuteUser == null
                          ? null
                          : () => widget.onUnmuteUser!(
                              comment.userId,
                              comment.username,
                            ),
                      onBan: widget.onBanUser == null
                          ? null
                          : () => widget.onBanUser!(
                              comment.userId,
                              comment.username,
                              null,
                            ),
                      onUnban: widget.onUnbanUser == null
                          ? null
                          : () => widget.onUnbanUser!(
                              comment.userId,
                              comment.username,
                            ),
                    )
                    .animate(key: ValueKey(comment.id))
                    .fadeIn(duration: 140.ms)
                    .slideY(begin: 0.12, end: 0, duration: 180.ms);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class TikTokCommentBubble extends StatelessWidget {
  final CommentEntity comment;
  final bool highContrast;
  final bool showModerationMenu;
  final bool isMuted;
  final bool isBanned;
  final VoidCallback? onDelete;
  final VoidCallback? onMute;
  final VoidCallback? onUnmute;
  final VoidCallback? onBan;
  final VoidCallback? onUnban;

  const TikTokCommentBubble({
    super.key,
    required this.comment,
    this.highContrast = false,
    this.showModerationMenu = false,
    this.isMuted = false,
    this.isBanned = false,
    this.onDelete,
    this.onMute,
    this.onUnmute,
    this.onBan,
    this.onUnban,
  });

  bool get _isJoin => comment.metadata?['type'] == 'join';
  bool get _isGift => comment.metadata?['type'] == 'gift';

  @override
  Widget build(BuildContext context) {
    if (_isJoin) {
      return Padding(
        padding: const EdgeInsets.only(bottom: TikTokLiveTokens.commentGap),
        child: Container(
          padding: highContrast
              ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: highContrast ? const Color(0xD90B0B0D) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
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
                    color: Colors.white,
                    shadows: const [],
                  ),
                ),
                const TextSpan(text: ' 👋', style: TextStyle(fontSize: 12)),
              ],
            ),
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
              color: highContrast
                  ? const Color(0xD90B0B0D)
                  : TikTokLiveTokens.frost(0.35),
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
                      errorWidget: (_, _, _) => FallbackAvatar(
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
      child: Container(
        key: ValueKey('comment-bubble-${comment.id}'),
        padding: const EdgeInsets.fromLTRB(5, 4, 9, 4),
        decoration: BoxDecoration(
          color: highContrast ? const Color(0xD90B0B0D) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: highContrast
              ? Border.all(color: const Color(0x24FFFFFF), width: 0.5)
              : null,
        ),
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
                  errorWidget: (_, _, _) => FallbackAvatar(
                    seed: comment.userId,
                    name: comment.username,
                    radius: 12,
                  ),
                  placeholder: (_, _) => FallbackAvatar(
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
            if (showModerationMenu) ...[
              const SizedBox(width: 4),
              _CommentModerationMenu(
                isMuted: isMuted,
                isBanned: isBanned,
                onDelete: onDelete,
                onMute: onMute,
                onUnmute: onUnmute,
                onBan: onBan,
                onUnban: onUnban,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommentModerationMenu extends StatelessWidget {
  final bool isMuted;
  final bool isBanned;
  final VoidCallback? onDelete;
  final VoidCallback? onMute;
  final VoidCallback? onUnmute;
  final VoidCallback? onBan;
  final VoidCallback? onUnban;

  const _CommentModerationMenu({
    required this.isMuted,
    required this.isBanned,
    this.onDelete,
    this.onMute,
    this.onUnmute,
    this.onBan,
    this.onUnban,
  });

  Future<void> _showMenu(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _MenuTile(
                  icon: Icons.delete_outline,
                  label: 'Delete comment',
                  color: Colors.white,
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
                _MenuTile(
                  icon: isMuted ? Icons.chat : Icons.chat_bubble_outline,
                  label: isMuted ? 'Unmute chat' : 'Mute chat',
                  color: const Color(0xFFFFB020),
                  onTap: () => Navigator.pop(ctx, isMuted ? 'unmute' : 'mute'),
                ),
                _MenuTile(
                  icon: isBanned ? Icons.person_add : Icons.block,
                  label: isBanned ? 'Unban user' : 'Ban from live',
                  color: const Color(0xFFFF2D55),
                  onTap: () => Navigator.pop(ctx, isBanned ? 'unban' : 'ban'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == null) return;
    switch (result) {
      case 'delete':
        onDelete?.call();
        break;
      case 'mute':
        onMute?.call();
        break;
      case 'unmute':
        onUnmute?.call();
        break;
      case 'ban':
        onBan?.call();
        break;
      case 'unban':
        onUnban?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMenu(context),
      child: const SizedBox(
        width: 22,
        height: 22,
        child: Icon(Icons.more_vert, color: Colors.white54, size: 18),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
    // Same left-edge anchor as the feed below it: the bar keeps its pin
    // icon on the left in Arabic instead of mirroring to the RTL start.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
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
      ),
    );
  }
}
