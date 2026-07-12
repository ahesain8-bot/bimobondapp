import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/posts/domain/usecases/record_post_view_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/data/viewed_stories_store.dart';

/// Records at most one successful POST /posts/:id/view per post id per session.
///
/// Story screens can also skip ids already persisted in [ViewedStoriesStore].
class PostViewRecorder {
  PostViewRecorder._();

  static final Set<String> _recordedIds = {};
  static final Set<String> _inFlightIds = {};

  static bool _wasStoryViewedBefore(String postId) {
    try {
      return auth_di.sl<ViewedStoriesStore>().isViewed(postId);
    } catch (_) {
      return false;
    }
  }

  /// Returns the server view count when the request succeeds.
  static Future<int?> recordIfNeeded({
    required String postId,
    bool isOwner = false,
    int? watchedDuration,
    bool checkStoryHistory = false,
  }) async {
    if (isOwner ||
        postId.isEmpty ||
        _recordedIds.contains(postId) ||
        _inFlightIds.contains(postId)) {
      return null;
    }
    if (checkStoryHistory && _wasStoryViewedBefore(postId)) {
      return null;
    }

    _inFlightIds.add(postId);
    try {
      final result = await posts_di.sl<RecordPostViewUseCase>()(
        RecordPostViewParams(
          postId: postId,
          watchedDuration: watchedDuration,
        ),
      );

      return result.fold((_) => null, (count) {
        _recordedIds.add(postId);
        return count;
      });
    } finally {
      _inFlightIds.remove(postId);
    }
  }
}
