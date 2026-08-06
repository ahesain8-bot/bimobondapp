import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/posts/domain/usecases/record_post_view_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/app/stories/domain/usecases/stories_usecases.dart';
import 'package:bimobondapp/app/stories/presentation/di/stories_injector.dart'
    as stories_di;
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/data/viewed_stories_store.dart';

/// Records at most one successful view per content id + traffic source per session.
///
/// Stories use `POST /stories/:id/view`; posts use `POST /posts/:id/view`.
class PostViewRecorder {
  PostViewRecorder._();

  static final Set<String> _recordedKeys = {};
  static final Set<String> _inFlightKeys = {};

  static String _key(
    String postId,
    String trafficSource, {
    required bool isStory,
  }) {
    final source = trafficSource.trim().isEmpty
        ? TrafficSource.forYou
        : trafficSource.trim().toUpperCase();
    return '${isStory ? 'story' : 'post'}:$postId:$source';
  }

  static bool _wasStoryViewedBefore(String postId) {
    try {
      return auth_di.sl<ViewedStoriesStore>().isViewed(postId);
    } catch (_) {
      return false;
    }
  }

  /// Returns the server view count when the request succeeds (posts),
  /// or `0` when a story view is newly recorded (stories API has no count).
  static Future<int?> recordIfNeeded({
    required String postId,
    bool isOwner = false,
    int? watchedDuration,
    String? campaignId,
    String trafficSource = TrafficSource.forYou,
    bool checkStoryHistory = false,
    bool isStory = false,
  }) async {
    final key = _key(
      postId,
      trafficSource,
      isStory: isStory || checkStoryHistory,
    );
    if (isOwner ||
        postId.isEmpty ||
        _recordedKeys.contains(key) ||
        _inFlightKeys.contains(key)) {
      return null;
    }
    if (checkStoryHistory && _wasStoryViewedBefore(postId)) {
      return null;
    }

    _inFlightKeys.add(key);
    try {
      if (isStory || checkStoryHistory) {
        final result = await stories_di.sl<RecordStoryViewUseCase>()(
          RecordStoryViewParams(
            storyId: postId,
            watchedDuration: watchedDuration,
          ),
        );
        return result.fold((_) => null, (record) {
          _recordedKeys.add(key);
          try {
            auth_di.sl<ViewedStoriesStore>().markViewed(postId);
          } catch (_) {}
          // Story API does not return an updated count; signal success with 0
          // so callers can bump locally when recorded.
          return record.recorded ? 0 : null;
        });
      }

      final result = await posts_di.sl<RecordPostViewUseCase>()(
        RecordPostViewParams(
          postId: postId,
          watchedDuration: watchedDuration,
          campaignId: campaignId,
          trafficSource: trafficSource,
        ),
      );

      return result.fold((_) => null, (count) {
        _recordedKeys.add(key);
        return count;
      });
    } finally {
      _inFlightKeys.remove(key);
    }
  }
}
