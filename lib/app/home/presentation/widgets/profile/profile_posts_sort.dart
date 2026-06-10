import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';

/// Keeps profile grids ordered with the most recently added posts first.
void sortProfilePostsNewestFirst(List<PostEntity> posts) {
  posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
