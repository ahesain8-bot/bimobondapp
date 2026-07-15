import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/utils/gift_comment_l10n.dart';
import 'package:bimobondapp/core/utils/tag_parser.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/tagged_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CommentRow extends StatelessWidget {
  const CommentRow({
    required this.comment,
    required this.onLike,
    this.onReply,
    this.canDelete = false,
    this.onDelete,
    required this.l10n,
    this.isReply = false,
    super.key,
  });

  final CommentEntity comment;
  final bool Function() onLike;
  final VoidCallback? onReply;
  final bool canDelete;
  final VoidCallback? onDelete;
  final AppLocalizations l10n;
  final bool isReply;

  static const _likedRed = Color(0xFFFF2D55);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = comment.user.id;
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.45);
    final actionColor = onSurface.withValues(alpha: 0.55);
    final avatarRadius = isReply
        ? CommentLayout.replyAvatarRadius
        : CommentLayout.avatarRadius;
    final timeLabel = formatInboxTime(
      DateTime.tryParse(comment.createdAt),
      l10n,
    );
    final displayName = comment.user.username?.trim().isNotEmpty == true
        ? comment.user.username!.trim()
        : (comment.user.fullName?.trim().isNotEmpty == true
              ? comment.user.fullName!.trim()
              : 'user');

    void openProfile() {
      if (userId.isEmpty) return;
      openUserStoryOrProfile(
        context,
        userId: userId,
        username: comment.user.username,
        fullName: comment.user.fullName,
        avatarUrl: comment.user.avatarUrl,
      );
    }

    void toggleLike() {
      if (!onLike()) return;
      context.read<CommentsBloc>().add(
        ToggleLikeCommentRequested(comment.id, liked: !comment.isLiked),
      );
    }

    void handleReply() {
      if (!onLike()) return;
      onReply?.call();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StoryProfileAvatar(
          userId: userId,
          imageUrl: comment.user.avatarUrl,
          radius: avatarRadius,
          fallbackText: comment.user.fullName ?? comment.user.username ?? 'User',
          username: comment.user.username,
          fullName: comment.user.fullName,
          onTap: openProfile,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: openProfile,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              if (comment.isGift) ...[
                Builder(
                  builder: (context) {
                    final giftImage = giftCommentImageUrl(comment);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            localizedGiftCommentText(l10n, comment),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: onSurface,
                            ),
                          ),
                        ),
                        if (giftImage != null) ...[
                          const SizedBox(width: 8),
                          SafeNetworkImage(
                            imageUrl: giftImage,
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ] else
                TaggedText(
                  text: comment.content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: onSurface,
                  ),
                  mentionUserIds: MentionRefUtils.usernameToUserIdMap(
                    comment.content,
                    comment.mentions,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (timeLabel.isNotEmpty) ...[
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: onReply != null ? handleReply : null,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      l10n.replyAction,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: actionColor,
                      ),
                    ),
                  ),
                  if (canDelete && onDelete != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        LucideIcons.trash2,
                        size: 14,
                        color: actionColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          children: [
            GestureDetector(
              onTap: toggleLike,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  children: [
                    Icon(
                      comment.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: comment.isLiked ? _likedRed : muted,
                    ),
                    if (comment.likeCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatCompactCount(comment.likeCount),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: comment.isLiked ? _likedRed : muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Icon(LucideIcons.thumbsDown, size: 16, color: muted),
          ],
        ),
      ],
    );
  }
}
