import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_load_more.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:flutter/material.dart';

class ProfilePostsGridSliver extends StatelessWidget {
  const ProfilePostsGridSliver({
    required this.tab,
    required this.tabIndex,
    required this.emptyMessage,
    this.userId,
    super.key,
  });

  final ProfileTabPostsState tab;
  final int tabIndex;
  final String emptyMessage;
  final String? userId;

  static const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
    crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
    mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
    childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
  );

  bool get _showLoadMoreFooter =>
      tab.isLoadingMore && !tab.hasReachedMax && tab.posts.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tab.isRefreshing || (tab.isInitialLoading && tab.posts.isEmpty)) {
      return SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => SkeletonWidget(
            borderRadius: ProfileLayoutConstants.gridItemRadius,
          ),
          childCount: 9,
        ),
      );
    }

    if (tab.posts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: Center(
            child: CustomText(emptyMessage, variant: TextVariant.secondary),
          ),
        ),
      );
    }

    final grid = SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = tab.posts[index];
        return ProfileGridTile(
          post: post,
          tabIndex: tabIndex,
          theme: theme,
          onTap: () => openProfilePosts(
            context,
            posts: tab.posts,
            initialIndex: index,
            source: profilePostsSourceForTab(tabIndex),
            page: tab.page,
            hasReachedMax: tab.hasReachedMax,
            userId: userId,
          ),
        );
      }, childCount: tab.posts.length),
    );

    if (!_showLoadMoreFooter) return grid;

    return SliverMainAxisGroup(
      slivers: [
        grid,
        const SliverToBoxAdapter(child: ProfilePostsLoadMoreFooter()),
      ],
    );
  }
}
