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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = comment.user.id;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final actionColor = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final avatarRadius = isReply
        ? CommentLayout.replyAvatarRadius
        : CommentLayout.avatarRadius;
    final timeLabel = formatInboxTime(
      DateTime.tryParse(comment.createdAt),
      l10n,
    );

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
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: openProfile,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        comment.user.fullName?.trim().isNotEmpty == true
                            ? comment.user.fullName!.trim()
                            : (comment.user.username ?? 'user'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (comment.isGift)
                Text(
                  localizedGiftCommentText(l10n, comment),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
                )
              else
                TaggedText(
                  text: comment.content,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
                  mentionUserIds: MentionRefUtils.usernameToUserIdMap(
                    comment.content,
                    comment.mentions,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  GestureDetector(
                    onTap: toggleLike,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          comment.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 17,
                          color: comment.isLiked ? Colors.red : actionColor,
                        ),
                        if (comment.likeCount > 0) ...[
                          const SizedBox(width: 5),
                          Text(
                            formatCompactCount(comment.likeCount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: actionColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: onReply != null ? handleReply : null,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      l10n.replyAction,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: actionColor,
                      ),
                    ),
                  ),
                  if (canDelete && onDelete != null) ...[
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        LucideIcons.trash2,
                        size: 15,
                        color: actionColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
