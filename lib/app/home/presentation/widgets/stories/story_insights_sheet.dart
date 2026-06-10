import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_engagement_users_tab.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
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
    return GlassBottomSheet.showDraggable<void>(
      context,
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      adaptTheme: true,
      builder: (context, scrollController) => StoryInsightsSheet(
        postId: postId,
        likeCount: likeCount,
        viewCount: viewCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
