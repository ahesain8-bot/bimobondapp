import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/domain/entities/user_comment_entity.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/widgets/activity_feed_card.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserCommentListTile extends StatelessWidget {
  const UserCommentListTile({
    required this.comment,
    this.authorFallback,
    super.key,
  });

  final UserCommentEntity comment;
  final SocialUserEntity? authorFallback;

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

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await posts_di.sl<GetPostByIdUseCase>()(postId);

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    result.fold(
      (failure) => PopupDialogs.showErrorDialog(context, failure.message),
      (post) => openPost(context, post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final author = _author;
    final authorName =
        author?.displayName ?? l10n.messagesInboxUserFallback;
    final time = formatInboxTime(_createdAt, l10n);

    return ActivityFeedCard(
      badgeColor: MessagesLayoutConstants.activityCommentsColor,
      badgeIcon: Icons.chat_bubble_rounded,
      onTap: () => _openCommentedPost(context),
      avatar: StoryProfileAvatar(
        userId: author?.id,
        imageUrl: author?.avatarUrl,
        radius: 24,
        fallbackText: authorName,
        username: author?.username,
        fullName: author?.fullName,
        isFollowing: author?.isFollowing,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivityFeedActionText(
            actorName: authorName,
            action: l10n.userCommentAction,
            time: time,
            extra: comment.isReply ? l10n.userCommentReplyLabel : null,
          ),
          if (comment.content.trim().isNotEmpty)
            ActivityFeedQuoteBox(text: comment.content.trim()),
        ],
      ),
    );
  }
}
