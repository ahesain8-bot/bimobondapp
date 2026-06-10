import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum ProfilePostsViewerSource {
  ownPosts,
  ownReposts,
  ownOnlyMe,
  ownLiked,
  ownSaved,
  userPosts,
}

ProfilePostsViewerSource profilePostsSourceForTab(int tabIndex) {
  switch (tabIndex) {
    case ProfileLayoutConstants.repostsTabIndex:
      return ProfilePostsViewerSource.ownReposts;
    case ProfileLayoutConstants.onlyMeTabIndex:
      return ProfilePostsViewerSource.ownOnlyMe;
    case ProfileLayoutConstants.likedTabIndex:
      return ProfilePostsViewerSource.ownLiked;
    case ProfileLayoutConstants.savedTabIndex:
      return ProfilePostsViewerSource.ownSaved;
    default:
      return ProfilePostsViewerSource.ownPosts;
  }
}

class ProfilePostsOpenArgs {
  const ProfilePostsOpenArgs({
    required this.posts,
    required this.initialIndex,
    required this.source,
    required this.page,
    required this.hasReachedMax,
    this.userId,
  });

  final List<PostEntity> posts;
  final int initialIndex;
  final ProfilePostsViewerSource source;
  final int page;
  final bool hasReachedMax;
  final String? userId;
}

ProfilePostsOpenArgs? profilePostsOpenArgsFromExtra(Object? extra) {
  return extra is ProfilePostsOpenArgs ? extra : null;
}

void openProfilePosts(
  BuildContext context, {
  required List<PostEntity> posts,
  required int initialIndex,
  required ProfilePostsViewerSource source,
  required int page,
  required bool hasReachedMax,
  String? userId,
}) {
  if (posts.isEmpty || initialIndex < 0 || initialIndex >= posts.length) {
    return;
  }

  context.pushNamed(
    'profile_posts_viewer',
    extra: ProfilePostsOpenArgs(
      posts: posts,
      initialIndex: initialIndex,
      source: source,
      page: page,
      hasReachedMax: hasReachedMax,
      userId: userId,
    ),
  );
}
