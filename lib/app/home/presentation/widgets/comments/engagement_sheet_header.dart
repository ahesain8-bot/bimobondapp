import 'package:bimobondapp/app/home/presentation/widgets/comments/comment_sort_menu.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/engagement_tab.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    required this.onClose,
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
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.4);

    return DraggableSheetDragRegion(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSizes.p16,
              end: AppSizes.p8,
              top: 2,
              bottom: 2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorWeight: 2,
                    indicatorColor: onSurface,
                    dividerHeight: 0,
                    labelPadding: const EdgeInsetsDirectional.only(end: 18),
                    labelColor: onSurface,
                    unselectedLabelColor: muted,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    tabs: [
                      EngagementTab(
                        label:
                            '${l10n.commentsTitle} ${formatCompactCount(commentCount)}',
                      ),
                      EngagementTab(
                        label: '${l10n.likes} ${formatCompactCount(likeCount)}',
                      ),
                      if (isPostOwner)
                        EngagementTab(
                          label:
                              '${l10n.viewsLabel} ${formatCompactCount(viewCount)}',
                        ),
                    ],
                  ),
                ),
                if (showCommentSort)
                  CommentSortMenu(
                    sort: commentSort,
                    onSortChanged: onCommentSortChanged,
                    iconOnly: true,
                  ),
                IconButton(
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: Icon(LucideIcons.x, size: 22, color: onSurface),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: onSurface.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}
