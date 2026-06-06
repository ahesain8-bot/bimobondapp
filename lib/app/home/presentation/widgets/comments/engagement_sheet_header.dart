import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_sort_menu.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/engagement_tab.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class EngagementSheetHeader extends StatelessWidget {
  const EngagementSheetHeader({
    required this.tabController,
    required this.isPostOwner,
    required this.showCommentSort,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.commentSort,
    required this.onCommentSortChanged,
    super.key,
  });

  final TabController tabController;
  final bool isPostOwner;
  final bool showCommentSort;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final String commentSort;
  final ValueChanged<String> onCommentSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const SizedBox(height: AppSizes.p10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.dividerColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSizes.p16,
            end: AppSizes.p8,
            top: AppSizes.p4,
            bottom: AppSizes.p4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isPostOwner)
                Expanded(
                  child: TabBar(
                    controller: tabController,
                    isScrollable: false,
                    tabAlignment: TabAlignment.fill,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p10,
                      vertical: AppSizes.p8,
                    ),
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.p8,
                      vertical: AppSizes.p8,
                    ),
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                    indicatorColor: theme.colorScheme.primary,
                    dividerHeight: 0,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    tabs: [
                      EngagementTab(
                        label: '${l10n.likes} ${formatCompactCount(likeCount)}',
                      ),
                      EngagementTab(
                        label:
                            '${l10n.commentsTitle} ${formatCompactCount(commentCount)}',
                      ),
                      EngagementTab(
                        label:
                            '${l10n.viewsLabel} ${formatCompactCount(viewCount)}',
                      ),
                    ],
                  ),
                )
              else if (!showCommentSort)
                const SizedBox.shrink()
              else
                Expanded(
                  child: Text(
                    l10n.commentsTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              if (showCommentSort)
                CommentSortMenu(
                  sort: commentSort,
                  onSortChanged: onCommentSortChanged,
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.25),
        ),
      ],
    );
  }
}
