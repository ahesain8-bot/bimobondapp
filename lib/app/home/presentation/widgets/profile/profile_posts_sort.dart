import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';

/// Keeps profile grids ordered with pinned posts first, followed by the most recently added posts.
void sortProfilePostsNewestFirst(List<PostEntity> posts) {
  posts.sort((a, b) {
    if (a.isPinned && !b.isPinned) return -1;
    if (!a.isPinned && b.isPinned) return 1;
    return b.createdAt.compareTo(a.createdAt);
  });
}
