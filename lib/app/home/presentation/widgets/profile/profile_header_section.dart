import 'package:bimobondapp/app/auth/domain/entities/profile_enums.dart';
import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_verification_badge.dart';
import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_links_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_edit_pill_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_format_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_stat_item.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/profile_bio_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:bimobondapp/app/stories/domain/entities/highlight_entity.dart';
import 'package:bimobondapp/app/home/presentation/pages/stories_viewer_screen.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/auth/data/datasources/profile_remote_data_source.dart';

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    required this.user,
    required this.l10n,
    required this.onEditProfile,
    required this.onFollowersTap,
    required this.onFollowingTap,
    this.postsCount,
    this.highlights = const [],
    this.onAddHighlight,
    super.key,
  });

  final UserEntity user;
  final AppLocalizations l10n;
  final VoidCallback onEditProfile;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;
  final int? postsCount;
  final List<HighlightEntity> highlights;
  final VoidCallback? onAddHighlight;

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
                ProfileVerificationBadge(
                  badge: VerificationBadge.fromString(user.verificationBadge),
                  isVerified: user.isVerified == true,
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
          if (user.creatorCategory != null || user.pronouns != null || (user.accountType != null && user.accountType != 'PERSONAL')) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.accountType != null && user.accountType != 'PERSONAL') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.accountType == 'BUSINESS'
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
                if (user.creatorCategory != null && user.creatorCategory!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      user.creatorCategory!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (user.pronouns != null && user.pronouns!.isNotEmpty)
                  Text(
                    '(${user.pronouns})',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ],
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
              const _StatDivider(),
              Expanded(
                child: ProfileStatItem(
                  number: formatProfileCount(user.followerCount ?? 0),
                  label: l10n.followers,
                  onTap: onFollowersTap,
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: ProfileStatItem(
                  number: formatProfileCount(user.totalLikes ?? 0),
                  label: l10n.likes,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.p12),
          ProfileBioText(
            bio: bio,
            placeholder: l10n.addBioToProfile,
            onTap: hasBio ? null : onEditProfile,
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () => ProfileLinksSheet.show(context, user: user),
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
                  (user.websiteUrl?.isNotEmpty == true)
                      ? user.websiteUrl!
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
          // Story Highlights Row (directly under links)
          Builder(
            builder: (context) {
              final visibleHighlights = (onAddHighlight != null)
                  ? highlights
                  : highlights
                      .where(
                        (h) =>
                            h.stories.isNotEmpty ||
                            (h.coverUrl != null && h.coverUrl!.isNotEmpty),
                      )
                      .toList();

              if (onAddHighlight == null && visibleHighlights.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 104,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount:
                          visibleHighlights.length + (onAddHighlight != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        final cs = theme.colorScheme;
                        if (onAddHighlight != null && index == 0) {
                    return GestureDetector(
                      onTap: onAddHighlight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: cs.onSurface.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.add,
                                    color: cs.onSurface.withValues(alpha: 0.8),
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 76,
                              child: Text(
                                l10n.newHighlightButton,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final h = highlights[onAddHighlight != null ? index - 1 : index];
                  String? displayImage = h.coverUrl;
                  if ((displayImage == null || displayImage.isEmpty) && h.stories.isNotEmpty) {
                    displayImage = h.stories.first.thumbnailUrl ?? h.stories.first.videoUrl;
                  }

                  return GestureDetector(
                    onTap: () async {
                      List<PostEntity> highlightPosts = [];
                      if (h.stories.isNotEmpty) {
                        highlightPosts =
                            h.stories.map((s) => s.toPostEntity()).toList();
                      } else {
                        try {
                          final fullHighlight =
                              await ProfileRemoteDataSourceImpl()
                                  .getHighlightById(h.id);
                          highlightPosts = fullHighlight.stories
                              .map((s) => s.toPostEntity())
                              .toList();
                        } catch (_) {}
                      }

                      if (highlightPosts.isNotEmpty && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoriesViewerScreen(
                              stories: highlightPosts,
                              initialIndex: 0,
                              highlightId: h.id,
                              highlightTitle: h.title,
                            ),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cs.onSurface.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.scaffoldBackgroundColor,
                              ),
                              child: ClipOval(
                                child: (displayImage != null && displayImage.isNotEmpty)
                                    ? Image.network(
                                        displayImage,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: cs.surfaceContainerHighest,
                                          child: Center(
                                            child: Icon(
                                              Icons.star_rounded,
                                              color: Colors.amber.shade600,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: cs.surfaceContainerHighest,
                                        child: Center(
                                          child: Icon(
                                            Icons.star_rounded,
                                            color: Colors.amber.shade600,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 76,
                            child: Text(
                              h.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
          const SizedBox(height: AppSizes.p8),
        ],
      ),
    );
  }
}

/// Hairline between the three counters, as TikTok separates them.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: AppSizes.p24,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.14),
    );
  }
}
