import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_engagement_users_tab.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Story owner insights: who liked and who viewed.
class StoryInsightsSheet extends StatelessWidget {
  const StoryInsightsSheet({
    required this.postId,
    required this.likeCount,
    required this.viewCount,
    super.key,
  });

  final String postId;
  final int likeCount;
  final int viewCount;

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required int likeCount,
    required int viewCount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => StoryInsightsSheet(
          postId: postId,
          likeCount: likeCount,
          viewCount: viewCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.p16),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.p10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            TabBar(
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.55),
              indicatorColor: theme.colorScheme.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  text:
                      '${l10n.likes} (${formatCompactCount(likeCount)})',
                ),
                Tab(
                  text:
                      '${l10n.storyViewersTitle} (${formatCompactCount(viewCount)})',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  PostEngagementUsersTab(
                    postId: postId,
                    kind: PostEngagementUserListKind.likes,
                  ),
                  PostEngagementUsersTab(
                    postId: postId,
                    kind: PostEngagementUserListKind.views,
                    hideFollowForViewers: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
