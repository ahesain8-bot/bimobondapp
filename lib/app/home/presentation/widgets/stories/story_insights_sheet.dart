import 'package:bimobondapp/app/home/presentation/utils/story_grouping.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_engagement_users_tab.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Story owner viewers sheet (theme surface: white in light, dark in dark).
class StoryInsightsSheet extends StatelessWidget {
  const StoryInsightsSheet({
    required this.post,
    required this.viewCount,
    this.likeCount = 0,
    this.onDelete,
    super.key,
  });

  final PostEntity post;
  final int viewCount;
  final int likeCount;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required PostEntity post,
    required int viewCount,
    int likeCount = 0,
    VoidCallback? onDelete,
  }) {
    return GlassBottomSheet.showDraggable<void>(
      context,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      lightSurface: true,
      showHandle: true,
      builder: (context, scrollController) => StoryInsightsSheet(
        post: post,
        viewCount: viewCount,
        likeCount: likeCount,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final thumbUrl = post.thumbnailUrl ?? storyDisplayMediaUrl(post);

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.p8,
              AppSizes.p4,
              AppSizes.p8,
              AppSizes.p8,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete?.call();
                  },
                  icon: Icon(
                    LucideIcons.trash2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 52,
                        height: 72,
                        child: thumbUrl == null || thumbUrl.isEmpty
                            ? ColoredBox(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  LucideIcons.image,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                ),
                              )
                            : SafeNetworkImage(
                                imageUrl: thumbUrl,
                                fit: BoxFit.cover,
                                blankOnError: true,
                                showLoadingIndicator: false,
                              ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    LucideIcons.x,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.p8),
            child: Column(
              children: [
                Text(
                  '${formatCompactCount(viewCount)} ${l10n.viewsLabel.toLowerCase()}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (likeCount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.favorite,
                        size: 14,
                        color: Color(0xFFE1306C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatCompactCount(likeCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PostEngagementUsersTab(
              postId: post.id,
              kind: PostEngagementUserListKind.views,
              hideFollowForViewers: true,
              hideFollowButton: true,
              showMessageButton: true,
              showLikedHeart: false,
              isStory: true,
            ),
          ),
        ],
      ),
    );
  }
}
