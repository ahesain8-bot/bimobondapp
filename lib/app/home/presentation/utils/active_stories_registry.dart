import 'package:bimobondapp/app/home/presentation/utils/story_grouping.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:flutter/foundation.dart';

/// In-memory index of active stories by author (updated from feed/stories fetch).
class ActiveStoriesRegistry extends ChangeNotifier {
  Map<String, StoryUserGroup> _groupsByUserId = {};

  void updateFromStories(List<PostEntity> stories) {
    final groups = groupStoriesByUser(stories);
    _groupsByUserId = {for (final g in groups) g.userId: g};
    notifyListeners();
  }

  StoryUserGroup? groupFor(String userId) => _groupsByUserId[userId];

  List<PostEntity> activeStoriesFor(String userId) {
    final group = groupFor(userId);
    if (group == null) return const [];
    return onlyStoryPosts(group.stories);
  }

  bool hasActiveStories(String userId) {
    if (userId.isEmpty) return false;
    return activeStoriesFor(userId).isNotEmpty;
  }
}
