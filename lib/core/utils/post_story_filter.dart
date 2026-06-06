import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';

bool parsePostIsStory(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  if (value is num) return value != 0;
  return false;
}

/// Feed/profile lists: regular posts only.
List<PostEntity> excludeStoryPosts(List<PostEntity> posts) =>
    posts.where((post) => !post.isStory).toList();

/// Stories disappear 24 hours after creation.
const Duration storyLifetime = Duration(hours: 24);

bool isStoryStillActive(PostEntity post) {
  if (!post.isStory) return false;
  return DateTime.now().difference(post.createdAt) < storyLifetime;
}

Duration storyTimeRemaining(PostEntity post) {
  final elapsed = DateTime.now().difference(post.createdAt);
  final left = storyLifetime - elapsed;
  return left.isNegative ? Duration.zero : left;
}

/// Stories rail / viewer: active story posts only (within 24h).
List<PostEntity> onlyStoryPosts(List<PostEntity> posts) =>
    posts.where((post) => post.isStory && isStoryStillActive(post)).toList();
