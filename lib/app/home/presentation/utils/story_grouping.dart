import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';

class StoryUserGroup {
  const StoryUserGroup({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.stories,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final List<PostEntity> stories;
}

/// Groups active story posts by author (newest story first per user).
List<StoryUserGroup> groupStoriesByUser(List<PostEntity> stories) {
  final active = onlyStoryPosts(stories);
  final sorted = List<PostEntity>.from(active)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final map = <String, List<PostEntity>>{};
  for (final story in sorted) {
    map.putIfAbsent(story.userId, () => []).add(story);
  }

  return map.entries.map((entry) {
    final first = entry.value.first;
    final user = first.user;
    return StoryUserGroup(
      userId: entry.key,
      displayName: user?.username ?? entry.key,
      avatarUrl: user?.avatarUrl,
      stories: entry.value,
    );
  }).toList();
}

String? storyDisplayMediaUrl(PostEntity post) {
  if (post.type == 'VIDEO') {
    return post.videoUrl ?? post.thumbnailUrl;
  }
  if (post.media.isNotEmpty) {
    return post.media.first.url;
  }
  return post.thumbnailUrl ?? post.videoUrl;
}
