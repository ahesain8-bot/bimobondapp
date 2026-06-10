import 'package:bimobondapp/app/chats/presentation/utils/chat_message_mapper.dart';
import 'package:bimobondapp/app/social/domain/entities/user_like_entity.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/activity_feed_card.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserLikeListTile extends StatelessWidget {
  const UserLikeListTile({
    required this.like,
    super.key,
  });

  final UserLikeEntity like;

  DateTime? get _likedAt {
    if (like.createdAt.isEmpty) return null;
    return DateTime.tryParse(like.createdAt);
  }

  String? _resolveThumbnailUrl() {
    final post = like.post;
    if (post == null) return null;
    final thumb = post.thumbnailUrl;
    if (thumb != null && MediaUtils.isImage(thumb)) return thumb;
    if (post.media.isNotEmpty) {
      final first = post.media.first;
      if (MediaUtils.isImage(first.url, mediaType: first.mediaType)) {
        return first.url;
      }
    }
    return thumb;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final liker = like.user;
    final likerName = liker?.displayName ?? l10n.messagesInboxUserFallback;
    final time = formatInboxTime(_likedAt, l10n);
    final thumbnailUrl = _resolveThumbnailUrl();

    Future<void> openLikerProfile() async {
      if (liker == null || liker.id.isEmpty) return;
      await openUserStoryOrProfile(
        context,
        userId: liker.id,
        username: liker.username,
        fullName: liker.fullName,
        avatarUrl: liker.avatarUrl,
        isFollowing: liker.isFollowing,
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
      badgeColor: MessagesLayoutConstants.activityLikesColor,
      badgeIcon: Icons.favorite_rounded,
      onTap: () => openPostById(context, like.postId),
      avatar: StoryProfileAvatar(
        userId: liker?.id,
        imageUrl: liker?.avatarUrl,
        radius: 24,
        fallbackText: likerName,
        username: liker?.username,
        fullName: liker?.fullName,
        isFollowing: liker?.isFollowing,
        onTap: openLikerProfile,
      ),
      trailing: trailing,
      content: ActivityFeedActionText(
        actorName: likerName,
        action: l10n.userLikeReceivedAction,
        time: time,
      ),
    );
  }
}
