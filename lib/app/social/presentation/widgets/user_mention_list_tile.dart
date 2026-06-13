import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/mention_post_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/activity_feed_list_row.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserMentionListTile extends StatelessWidget {
  const UserMentionListTile({
    required this.mention,
    this.showDivider = true,
    super.key,
  });

  final UserMentionEntity mention;
  final bool showDivider;

  DateTime? get _createdAt {
    if (mention.createdAt.isEmpty) return null;
    return DateTime.tryParse(mention.createdAt);
  }

  String? _resolveThumbnailUrl() {
    final post = mention.post;
    if (post == null) return null;

    if (post.thumbnailUrl != null &&
        MediaUtils.isImage(post.thumbnailUrl!)) {
      return post.thumbnailUrl;
    }
    if (post.media.isNotEmpty) {
      final first = post.media.first;
      if (MediaUtils.isImage(first.url, mediaType: first.mediaType)) {
        return first.url;
      }
    }
    return post.thumbnailUrl;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final author = mention.user;
    final authorName =
        author?.displayName ?? l10n.messagesInboxUserFallback;
    final thumbnailUrl = _resolveThumbnailUrl();
    final content = mention.content.trim();

    void openAuthorProfile() {
      if (author == null || author.id.isEmpty) return;
      openUserStoryOrProfile(
        context,
        userId: author.id,
        username: author.username,
        fullName: author.fullName,
        avatarUrl: author.avatarUrl,
        isFollowing: author.isFollowing,
      );
    }

    return ActivityFeedListRow(
      actorName: authorName,
      actionPhrase: l10n.userMentionAction,
      extraPhrase:
          mention.isCommentMention ? l10n.userMentionInComment : null,
      onTap: () => openMentionPost(context, mention),
      userId: author?.id,
      imageUrl: author?.avatarUrl,
      username: author?.username,
      fullName: author?.fullName,
      isFollowing: author?.isFollowing,
      onAvatarTap: openAuthorProfile,
      createdAt: _createdAt,
      quoteText: content.isNotEmpty ? content : null,
      mediaThumbnailUrl: thumbnailUrl,
      mediaTitle: l10n.notificationContextPost,
      mediaSubtitle: l10n.notificationContextPost,
      showDivider: showDivider,
    );
  }
}
