import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/close_friends_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_links_sheet.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_verification_badge.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/user_profile_stat_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar_tap_handler.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/app/social/presentation/widgets/profile_follow_button.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/profile_bio_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserProfileHeaderDetails extends StatelessWidget {
  const UserProfileHeaderDetails({
    required this.user,
    required this.userId,
    required this.username,
    required this.isSelf,
    required this.isLoadingUser,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isFollowLoading,
    required this.isMessageLoading,
    required this.displayPostCount,
    required this.onToggleFollow,
    required this.onOpenMessage,
    required this.onNavigateFollowers,
    required this.onNavigateFollowing,
    super.key,
  });

  final UserEntity? user;
  final String userId;
  final String username;
  final bool isSelf;
  final bool isLoadingUser;
  final bool isFollowing;
  final bool isFollowedBy;
  final bool isFollowLoading;
  final bool isMessageLoading;
  final int displayPostCount;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpenMessage;
  final VoidCallback onNavigateFollowers;
  final VoidCallback onNavigateFollowing;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: AppSizes.p12),
        if (isLoadingUser && user == null)
          const SkeletonWidget.circular(size: 96)
        else
          StoryProfileAvatar(
            userId: userId,
            imageUrl: user?.avatarUrl,
            radius: ProfileLayoutConstants.avatarRadius,
            fallbackText: user?.username ?? username,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.08),
            username: user?.username ?? username,
            fullName: user?.fullName,
            isFollowing: isFollowing,
            onTap: () => handleProfileScreenAvatarTap(
              context,
              userId: userId,
              avatarUrl: user?.avatarUrl,
            ),
          ),
        const SizedBox(height: AppSizes.p12),
        if (isLoadingUser && user?.fullName == null)
          const SkeletonWidget(height: 18, width: 160)
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user?.fullName?.trim().isNotEmpty == true
                    ? user!.fullName!.trim()
                    : username,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              ProfileVerificationBadge(
                badge: VerificationBadge.fromString(user?.verificationBadge),
                isVerified: user?.isVerified == true,
              ),
            ],
          ),
        const SizedBox(height: AppSizes.p6),
        CustomText(
          '@$username',
          fontSize: 14,
          variant: TextVariant.secondary,
          textAlign: TextAlign.center,
        ),
        if (user?.creatorCategory != null ||
            user?.pronouns != null ||
            (user?.accountType != null && user?.accountType != 'PERSONAL')) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user?.accountType != null &&
                  user?.accountType != 'PERSONAL') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user!.accountType == 'BUSINESS'
                        ? l10n.accountTypeBusiness
                        : l10n.accountTypeCreator,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (user?.creatorCategory != null &&
                  user!.creatorCategory!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user!.creatorCategory!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (user?.pronouns != null && user!.pronouns!.isNotEmpty)
                Text(
                  '(${user!.pronouns})',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
        if (!isSelf) ...[
          const SizedBox(height: AppSizes.p16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProfileFollowButton(
                width: 140,
                isFollowing: isFollowing,
                isFollowedBy: isFollowedBy,
                isLoading: isFollowLoading,
                onPressed: onToggleFollow,
              ),
              const SizedBox(width: AppSizes.p12),
              SizedBox(
                width: 140,
                height: 40,
                child: OutlinedButton(
                  onPressed: isMessageLoading ? null : onOpenMessage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  child: isMessageLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : CustomText(
                          l10n.profileMessageButton,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSizes.p16),
        Row(
          children: [
            Expanded(
              child: UserProfileStatItem(
                number: _formatCount(displayPostCount),
                label: l10n.profilePostsTab,
              ),
            ),
            Expanded(
              child: UserProfileStatItem(
                number: _formatCount(user?.followerCount ?? 0),
                label: l10n.followers,
                onTap: onNavigateFollowers,
              ),
            ),
            Expanded(
              child: UserProfileStatItem(
                number: _formatCount(user?.followingCount ?? 0),
                label: l10n.following,
                onTap: onNavigateFollowing,
              ),
            ),
          ],
        ),
        ProfileBioText(
          bio: user?.bio,
          placeholder: l10n.noBio,
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () {
            if (user != null) {
              ProfileLinksSheet.show(context, user: user!);
            }
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                (user?.websiteUrl?.isNotEmpty == true)
                    ? user!.websiteUrl!
                    : l10n.profileLinksTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
