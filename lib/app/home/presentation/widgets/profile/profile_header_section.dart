import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_edit_pill_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_format_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_stat_item.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    required this.user,
    required this.l10n,
    required this.onEditProfile,
    required this.onFollowersTap,
    required this.onFollowingTap,
    this.postsCount,
    super.key,
  });

  final UserEntity user;
  final AppLocalizations l10n;
  final VoidCallback onEditProfile;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final int? postsCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = user.username ?? 'username';
    final displayName = user.fullName?.trim().isNotEmpty == true
        ? user.fullName!.trim()
        : username;
    final bio = user.bio?.trim();
    final hasBio = bio != null && bio.isNotEmpty;
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileLayoutConstants.headerHorizontalPadding,
      ),
      child: Column(
        children: [
          ProfileAvatar(user: user),
          const SizedBox(height: AppSizes.p12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(
                  width: ProfileLayoutConstants.editPillGapFromName,
                ),
                ProfileEditPillButton(onPressed: onEditProfile),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.p4),
          Text(
            '@$username',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: secondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.p16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ProfileStatItem(
                  number: formatProfileCount(user.followingCount ?? 0),
                  label: l10n.following,
                  onTap: onFollowingTap,
                ),
              ),
              Expanded(
                child: ProfileStatItem(
                  number: formatProfileCount(user.followerCount ?? 0),
                  label: l10n.followers,
                  onTap: onFollowersTap,
                ),
              ),
              Expanded(
                child: ProfileStatItem(
                  number: formatProfileCount(user.totalLikes ?? 0),
                  label: l10n.likes,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          GestureDetector(
            onTap: hasBio ? null : onEditProfile,
            child: Text(
              hasBio ? bio : l10n.addBioToProfile,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasBio ? theme.colorScheme.onSurface : secondary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.p8),
        ],
      ),
    );
  }
}
