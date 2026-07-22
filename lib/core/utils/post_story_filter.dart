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

/// Stories disappear after TTL (default 24h, max 7 days on API).
const Duration storyLifetime = Duration(hours: 24);
const Duration storyMaxLifetime = Duration(hours: 168);

bool isStoryStillActive(PostEntity post) {
  if (!post.isStory) return false;
  // Soft client guard aligned with API max TTL; rings already filter expired.
  return DateTime.now().difference(post.createdAt) < storyMaxLifetime;
}

Duration storyTimeRemaining(PostEntity post) {
  final elapsed = DateTime.now().difference(post.createdAt);
  final left = storyLifetime - elapsed;
  return left.isNegative ? Duration.zero : left;
}

/// Stories rail / viewer: active story posts only (within 24h).
List<PostEntity> onlyStoryPosts(List<PostEntity> posts) =>
    posts.where((post) => post.isStory && isStoryStillActive(post)).toList();
