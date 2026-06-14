import 'package:bimobondapp/app/notifications/presentation/utils/notification_type_style.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/widgets/activity_feed_list_row.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserCommentListTile extends StatelessWidget {
  const UserCommentListTile({
    required this.comment,
    this.authorFallback,
    this.showDivider = true,
    super.key,
  });

  final UserCommentEntity comment;
  final SocialUserEntity? authorFallback;
  final bool showDivider;

  DateTime? get _createdAt {
    if (comment.createdAt.isEmpty) return null;
    return DateTime.tryParse(comment.createdAt);
  }

  SocialUserEntity? get _author {
    if (comment.user != null) return comment.user;
    if (authorFallback == null) return null;
    if (comment.userId.isNotEmpty && authorFallback!.id != comment.userId) {
      return SocialUserEntity(id: comment.userId);
    }
    return authorFallback;
  }

  Future<void> _openCommentedPost(BuildContext context) async {
    final postId = comment.postId.trim();
    if (postId.isEmpty) return;

    final commentId = comment.id.trim();
    await openPostById(
      context,
      postId,
      openComments: true,
      highlightCommentId: commentId.isNotEmpty ? commentId : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final author = _author;
    final authorName =
        author?.displayName ?? l10n.messagesInboxUserFallback;
    final (badgeIcon, badgeColor) = NotificationTypeStyle.forType('POST_COMMENT');

    return ActivityFeedListRow(
      actorName: authorName,
      actionPhrase: l10n.userCommentAction,
      extraPhrase: comment.isReply ? l10n.userCommentReplyLabel : null,
      onTap: () => _openCommentedPost(context),
      userId: author?.id,
      imageUrl: author?.avatarUrl,
      username: author?.username,
      fullName: author?.fullName,
      isFollowing: author?.isFollowing,
      createdAt: _createdAt,
      quoteText: comment.content.trim().isNotEmpty ? comment.content : null,
      badgeIcon: badgeIcon,
      badgeColor: badgeColor,
      showDivider: showDivider,
    );
  }
}
