import 'package:bimobondapp/app/notifications/presentation/utils/notification_type_style.dart';
import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/widgets/activity_feed_list_row.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class SocialUserListTile extends StatelessWidget {
  const SocialUserListTile({
    required this.user,
    required this.isSelf,
    this.isFollowLoading = false,
    this.onFollowTap,
    this.onTap,
    this.onProfileFollowStateChanged,
    this.subtitleOverride,
    this.hideFollowButton = false,
    this.useActivityCard = false,
    this.showDivider = true,
    this.trailingOverride,
    super.key,
  });

  final SocialUserEntity user;
  final bool isSelf;
  final bool hideFollowButton;
  final bool isFollowLoading;
  final VoidCallback? onFollowTap;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onProfileFollowStateChanged;
  final String? subtitleOverride;
  final bool useActivityCard;
  final bool showDivider;
  final Widget? trailingOverride;

  @override
  Widget build(BuildContext context) {
    if (useActivityCard) {
      return _buildActivityCard(context);
    }
    return _buildListTile(context);
  }

  Widget _buildActivityCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showFollowButton = !hideFollowButton && !isSelf;

    Future<void> openProfile() async {
      if (onTap != null) {
        onTap!();
        return;
      }
      final isFollowing = await openUserStoryOrProfile(
        context,
        userId: user.id,
        username: user.username,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        isFollowing: user.isFollowing,
      );
      if (isFollowing != null) {
        onProfileFollowStateChanged?.call(isFollowing);
      }
    }

    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : user.displayName;

    final (badgeIcon, badgeColor) = NotificationTypeStyle.forType('NEW_FOLLOWER');

    return ActivityFeedListRow(
      actorName: displayName,
      actionPhrase: l10n.userFollowerAction,
      onTap: openProfile,
      userId: user.id,
      imageUrl: user.avatarUrl,
      username: user.username,
      fullName: user.fullName,
      isFollowing: user.isFollowing,
      onAvatarTap: openProfile,
      showUsernameUnderName: true,
      compactPadding: true,
      badgeIcon: badgeIcon,
      badgeColor: badgeColor,
      trailing: showFollowButton
          ? ProfileFollowButton.listTile(
              isFollowing: user.isFollowing,
              isFollowedBy: user.isFollowedBy,
              isLoading: isFollowLoading,
              onPressed: onFollowTap,
            )
          : null,
      showDivider: showDivider,
    );
  }

  Widget _buildListTile(BuildContext context) {
    final theme = Theme.of(context);
    final handle = user.username?.trim();
    final showFollowButton = !hideFollowButton && !isSelf;

    Future<void> openProfile() async {
      if (onTap != null) {
        onTap!();
        return;
      }
      final isFollowing = await openUserStoryOrProfile(
        context,
        userId: user.id,
        username: user.username,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        isFollowing: user.isFollowing,
      );
      if (isFollowing != null) {
        onProfileFollowStateChanged?.call(isFollowing);
      }
    }

    return ListTile(
      onTap: openProfile,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: StoryProfileAvatar(
        userId: user.id,
        imageUrl: user.avatarUrl,
        fallbackText: user.displayName,
        radius: 24,
        username: user.username,
        fullName: user.fullName,
        isFollowing: user.isFollowing,
      ),
      title: Text(
        user.fullName ?? user.username ?? user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: _buildSubtitle(handle, subtitleOverride),
      trailing: trailingOverride ??
          (showFollowButton
              ? ProfileFollowButton.listTile(
                  isFollowing: user.isFollowing,
                  isFollowedBy: user.isFollowedBy,
                  isLoading: isFollowLoading,
                  onPressed: onFollowTap,
                )
              : null),
    );
  }

  Widget? _buildSubtitle(String? handle, String? extra) {
    final hasHandle = handle != null && handle.isNotEmpty;
    final hasExtra = extra != null && extra.isNotEmpty;
    if (!hasHandle && !hasExtra) return null;

    if (hasHandle && hasExtra) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomText('@$handle', fontSize: 13, variant: TextVariant.secondary),
          const SizedBox(height: 2),
          CustomText(extra, fontSize: 12, variant: TextVariant.secondary),
        ],
      );
    }
    if (hasHandle) {
      return CustomText('@$handle', fontSize: 13, variant: TextVariant.secondary);
    }
    return CustomText(extra!, fontSize: 12, variant: TextVariant.secondary);
  }
}
