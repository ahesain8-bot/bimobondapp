import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/social/domain/entities/user_mention_entity.dart';
import 'package:bimobondapp/app/social/presentation/utils/mention_post_navigation.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/activity_feed_card.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserMentionListTile extends StatelessWidget {
  const UserMentionListTile({
    required this.mention,
    super.key,
  });

  final UserMentionEntity mention;

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
    final time = formatInboxTime(_createdAt, l10n);
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

    Widget? trailing;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      trailing = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SafeNetworkImage(
          imageUrl: thumbnailUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorIcon: Icons.image_outlined,
        ),
      );
    }

    return ActivityFeedCard(
      badgeColor: MessagesLayoutConstants.activityMentionsColor,
      badgeIcon: Icons.alternate_email_rounded,
      onTap: () => openMentionPost(context, mention),
      avatar: StoryProfileAvatar(
        userId: author?.id,
        imageUrl: author?.avatarUrl,
        radius: 24,
        fallbackText: authorName,
        username: author?.username,
        fullName: author?.fullName,
        isFollowing: author?.isFollowing,
        onTap: openAuthorProfile,
      ),
      trailing: trailing,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivityFeedActionText(
            actorName: authorName,
            action: l10n.userMentionAction,
            time: time,
            extra: mention.isCommentMention ? l10n.userMentionInComment : null,
          ),
          if (content.isNotEmpty) ActivityFeedQuoteBox(text: content),
        ],
      ),
    );
  }
}
