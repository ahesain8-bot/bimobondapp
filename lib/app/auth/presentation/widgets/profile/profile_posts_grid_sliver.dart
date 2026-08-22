import 'package:bimobondapp/app/auth/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
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

    final displayPosts = <PostEntity>[];
    if (tabIndex == ProfileLayoutConstants.postsTabIndex) {
      final pinned = <PostEntity>[];
      final unpinned = <PostEntity>[];
      for (final p in tab.posts) {
        if (p.isPinned) {
          pinned.add(p);
        } else {
          unpinned.add(p);
        }
      }
      displayPosts.addAll([...pinned, ...unpinned]);
    } else {
      displayPosts.addAll(tab.posts);
    }

    final grid = SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = displayPosts[index];
        return ProfileGridTile(
          post: post,
          tabIndex: tabIndex,
          theme: theme,
          onTap: () => openProfilePosts(
            context,
            posts: displayPosts,
            initialIndex: index,
            source: profilePostsSourceForTab(tabIndex),
            page: tab.page,
            hasReachedMax: tab.hasReachedMax,
            userId: userId,
          ),
        );
      }, childCount: displayPosts.length),
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
