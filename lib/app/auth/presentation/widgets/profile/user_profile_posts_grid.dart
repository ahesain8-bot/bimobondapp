import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_load_more.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:flutter/material.dart';

class UserProfilePostsState {
  static const int pageSize = ProfileLayoutConstants.postsPageSize;

  int page = 1;
  bool isInitialLoading = true;
  bool isLoadingMore = false;
  bool isRefreshing = false;
  bool hasReachedMax = false;
  int? pendingLoadKey;

  List<PostEntity> posts = [];
}

class UserProfilePostsGrid extends StatelessWidget {
  const UserProfilePostsGrid({
    required this.state,
    required this.emptyMessage,
    required this.userId,
    this.pinnedPostIds = const [],
    this.pinnedPostsList = const [],
    this.onTogglePin,
    this.isSelf = false,
    this.tabIndex = ProfileLayoutConstants.postsTabIndex,
    super.key,
  });

  final UserProfilePostsState state;
  final String emptyMessage;
  final String userId;
  final List<String> pinnedPostIds;
  final List<PostEntity> pinnedPostsList;
  final Function(PostEntity)? onTogglePin;
  final bool isSelf;
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: ProfileLayoutConstants.gridCrossAxisCount,
      crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
      mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
      childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
    );

    final sourcePosts = state.posts.where((p) {
      if (tabIndex == ProfileLayoutConstants.auctionsTabIndex) {
        return p.isAuctionable || p.auction != null;
      } else {
        return !p.isAuctionable && p.auction == null;
      }
    }).toList();

    if (state.isRefreshing ||
        (state.isInitialLoading &&
            sourcePosts.isEmpty &&
            pinnedPostsList.isEmpty)) {
      return SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (_, _) => SkeletonWidget(
            borderRadius: ProfileLayoutConstants.gridItemRadius,
          ),
          childCount: 9,
        ),
      );
    }

    final pinnedPosts = <PostEntity>[];
    final unpinnedPosts = <PostEntity>[];
    final addedPinnedIds = <String>{};

    // 1. Add pinned posts from pinnedPostsList if still pinned in pinnedPostIds
    for (final p in pinnedPostsList) {
      if (tabIndex == ProfileLayoutConstants.postsTabIndex &&
          (p.isAuctionable || p.auction != null)) {
        continue;
      }
      final isStillPinned =
          pinnedPostIds.isEmpty || pinnedPostIds.contains(p.id);
      if (isStillPinned) {
        pinnedPosts.add(p.copyWith(isPinned: true));
        addedPinnedIds.add(p.id);
      }
    }

    // 2. Add pinned posts from sourcePosts
    for (final p in sourcePosts) {
      final isPinned = p.isPinned || pinnedPostIds.contains(p.id);
      if (isPinned) {
        if (!addedPinnedIds.contains(p.id)) {
          pinnedPosts.add(p.copyWith(isPinned: true));
          addedPinnedIds.add(p.id);
        }
      }
    }

    // 3. Add all unpinned posts
    for (final p in sourcePosts) {
      final isPinned = p.isPinned || pinnedPostIds.contains(p.id);
      if (!isPinned && !addedPinnedIds.contains(p.id)) {
        unpinnedPosts.add(p.copyWith(isPinned: false));
      }
    }

    final displayPosts = [...pinnedPosts, ...unpinnedPosts];

    if (displayPosts.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: Center(
            child: CustomText(emptyMessage, variant: TextVariant.secondary),
          ),
        ),
      );
    }

    final showLoadMoreFooter =
        state.isLoadingMore && !state.hasReachedMax && state.posts.isNotEmpty;

    final grid = SliverGrid(
      gridDelegate: gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        final post = displayPosts[index];
        final isPinned = post.isPinned;
        final tile = ProfileGridTile(
          post: post,
          tabIndex: ProfileLayoutConstants.postsTabIndex,
          theme: Theme.of(context),
          onTap: () => openProfilePosts(
            context,
            posts: displayPosts,
            initialIndex: index,
            source: ProfilePostsViewerSource.userPosts,
            page: state.page,
            hasReachedMax: state.hasReachedMax,
            userId: userId,
          ),
        );

        if (!isSelf || onTogglePin == null) return tile;

        return GestureDetector(
          onLongPress: () {
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.push_pin_rounded),
                      title: Text(
                        isPinned ? 'Unpin from profile' : 'Pin to profile',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        onTogglePin!(post);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: tile,
        );
      }, childCount: displayPosts.length),
    );

    if (!showLoadMoreFooter) return grid;

    return SliverMainAxisGroup(
      slivers: [
        grid,
        const SliverToBoxAdapter(child: ProfilePostsLoadMoreFooter()),
      ],
    );
  }
}
