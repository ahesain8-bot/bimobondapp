import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_tile.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_load_more.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_uploading_grid_tile.dart';
import 'package:bimobondapp/app/posts/presentation/utils/pending_post_uploads.dart';
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
    this.showPendingUploads = false,
    super.key,
  });

  final ProfileTabPostsState tab;
  final int tabIndex;
  final String emptyMessage;
  final String? userId;

  /// Own profile posts tab — show TikTok-style uploading tiles.
  final bool showPendingUploads;

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
    if (!showPendingUploads) {
      return _buildContent(context, const []);
    }
    return ListenableBuilder(
      listenable: PendingPostUploads.instance,
      builder: (context, _) =>
          _buildContent(context, PendingPostUploads.instance.items),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<PendingPostUpload> uploads,
  ) {
    final theme = Theme.of(context);

    if (tab.isRefreshing || (tab.isInitialLoading && tab.posts.isEmpty)) {
      if (uploads.isNotEmpty) {
        return SliverGrid(
          gridDelegate: _gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index < uploads.length) {
                return ProfileUploadingGridTile(upload: uploads[index]);
              }
              return SkeletonWidget(
                borderRadius: ProfileLayoutConstants.gridItemRadius,
              );
            },
            childCount: uploads.length + 3,
          ),
        );
      }
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

    if (tab.posts.isEmpty && uploads.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: Center(
            child: CustomText(emptyMessage, variant: TextVariant.secondary),
          ),
        ),
      );
    }

    final pendingCount = uploads.length;
    final total = pendingCount + tab.posts.length;

    final grid = SliverGrid(
      gridDelegate: _gridDelegate,
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < pendingCount) {
          return ProfileUploadingGridTile(upload: uploads[index]);
        }
        final postIndex = index - pendingCount;
        final post = tab.posts[postIndex];
        return ProfileGridTile(
          post: post,
          tabIndex: tabIndex,
          theme: theme,
          onTap: () => openProfilePosts(
            context,
            posts: tab.posts,
            initialIndex: postIndex,
            source: profilePostsSourceForTab(tabIndex),
            page: tab.page,
            hasReachedMax: tab.hasReachedMax,
            userId: userId,
          ),
        );
      }, childCount: total),
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
