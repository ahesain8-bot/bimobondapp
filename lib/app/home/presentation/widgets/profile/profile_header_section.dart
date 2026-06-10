import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_edit_pill_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_format_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_stat_item.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
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
              textDirection: TextDirection.ltr,
              children: [
                Flexible(
                  child: Text(
                    user.fullName ?? username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(
                  width: ProfileLayoutConstants.editPillGapFromName,
                ),
                ProfileEditPillButton(onPressed: onEditProfile),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.p6),
          CustomText(
            '@$username',
            fontSize: 14,
            variant: TextVariant.secondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.p16),
          Row(
            children: [
              Expanded(
                        child: ProfileStatItem(
                          number: formatProfileCount(
                            postsCount ?? user.postCount ?? 0,
                          ),
                          label: l10n.profilePostsTab,
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
                  number: formatProfileCount(user.followingCount ?? 0),
                  label: l10n.following,
                  onTap: onFollowingTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          CustomText(
            user.bio ?? l10n.noBio,
            fontSize: 14,
            variant: TextVariant.secondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
