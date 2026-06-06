import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/posts/domain/usecases/record_post_view_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/data/viewed_stories_store.dart';

/// Records at most one POST /posts/:id/view per post id (session + persisted for stories).
class PostViewRecorder {
  PostViewRecorder._();

  static final Set<String> _recordedIds = {};

  static bool _wasViewedBefore(String postId) {
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
  }) async {
    if (isOwner ||
        postId.isEmpty ||
        _wasViewedBefore(postId) ||
        _recordedIds.contains(postId)) {
      return null;
    }
    _recordedIds.add(postId);

    final result = await posts_di.sl<RecordPostViewUseCase>()(
      RecordPostViewParams(
        postId: postId,
        watchedDuration: watchedDuration,
      ),
    );
    return result.fold((_) => null, (count) => count);
  }
}
