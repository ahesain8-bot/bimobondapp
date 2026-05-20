import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/pages/video_post_widget.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/utils/one_page_scroll_physics.dart';
import 'package:flutter/material.dart';

class HomeFeedPageView extends StatelessWidget {
  const HomeFeedPageView({
    required this.controller,
    required this.posts,
    required this.currentPostIndex,
    required this.isTabActive,
    required this.onPageChanged,
    super.key,
  });

  final PageController controller;
  final List<PostEntity> posts;
  final int currentPostIndex;
  final bool isTabActive;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      physics: const OnePageScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: posts.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final post = posts[index];
        if (post.isAuctionable) {
          return LiveDetailsScreen(post: post, embeddedInFeed: true);
        }
        return VideoPostWidget(
          key: ValueKey(post.id),
          post: post,
          isActive: isTabActive && index == currentPostIndex,
          bottomPadding: HomeLayoutConstants.feedPostBottomPadding,
        );
      },
    );
  }
}
