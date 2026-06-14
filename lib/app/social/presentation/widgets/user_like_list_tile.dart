import 'package:bimobondapp/app/notifications/presentation/utils/notification_type_style.dart';
import 'package:bimobondapp/app/social/domain/entities/user_like_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/widgets/activity_feed_list_row.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserLikeListTile extends StatelessWidget {
  const UserLikeListTile({
    required this.like,
    this.showDivider = true,
    super.key,
  });

  final UserLikeEntity like;
  final bool showDivider;

  DateTime? get _likedAt {
    if (like.createdAt.isEmpty) return null;
    return DateTime.tryParse(like.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final liker = like.user;
    final likerName = liker?.displayName ?? l10n.messagesInboxUserFallback;
    final (badgeIcon, badgeColor) = NotificationTypeStyle.forType('POST_LIKE');

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

    return ActivityFeedListRow(
      actorName: likerName,
      actionPhrase: l10n.userLikeReceivedAction,
      onTap: () => openPostById(context, like.postId),
      userId: liker?.id,
      imageUrl: liker?.avatarUrl,
      username: liker?.username,
      fullName: liker?.fullName,
      isFollowing: liker?.isFollowing,
      onAvatarTap: openLikerProfile,
      createdAt: _likedAt,
      badgeIcon: badgeIcon,
      badgeColor: badgeColor,
      showDivider: showDivider,
    );
  }
}
