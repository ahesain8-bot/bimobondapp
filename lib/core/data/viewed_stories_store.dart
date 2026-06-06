import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which story post ids the current user has opened (gray ring on Messages).
class ViewedStoriesStore extends ChangeNotifier {
  ViewedStoriesStore(this._prefs);

  final SharedPreferences _prefs;
  final Set<String> _viewed = <String>{};
  String? _userId;

  static String _key(String userId) => 'viewed_stories_$userId';

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _viewed.clear();
    if (userId != null && userId.isNotEmpty) {
      _viewed.addAll(_prefs.getStringList(_key(userId)) ?? const []);
    }
    notifyListeners();
  }

  Future<void> markViewed(String storyPostId) async {
    if (_userId == null || _userId!.isEmpty || storyPostId.isEmpty) return;
    if (!_viewed.add(storyPostId)) return;
    await _prefs.setStringList(_key(_userId!), _viewed.toList());
    notifyListeners();
  }

  bool isViewed(String storyPostId) => _viewed.contains(storyPostId);

  /// True when every active story in the group has been seen.
  bool isGroupFullyViewed(List<PostEntity> stories) {
    final active = onlyStoryPosts(stories);
    if (active.isEmpty) return true;
    return active.every((s) => isViewed(s.id));
  }

  Future<void> clearForUser(String userId) async {
    await _prefs.remove(_key(userId));
    if (_userId == userId) {
      _viewed.clear();
      notifyListeners();
    }
  }
}
