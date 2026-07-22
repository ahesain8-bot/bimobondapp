import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/share_post_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/utils/api_constants.dart';

/// Tracks share activity via POST /posts/:id/share and returns the share URL.
class PostShareTracker {
  PostShareTracker._();

  static String fallbackLink(PostEntity post) =>
      '${ApiConstants.baseUrl}/posts/${post.id}';

  /// Fire-and-forget friendly: always returns a usable link.
  static Future<String> trackAndResolveLink(
    PostEntity post, {
    String channel = 'EXTERNAL',
  }) async {
    try {
      final result = await posts_di.sl<SharePostUseCase>()(
        SharePostParams(postId: post.id, channel: channel),
      );
      return result.fold(
        (_) => fallbackLink(post),
        (share) {
          final url = share.shareUrl;
          if (url != null && url.isNotEmpty) return url;
          return fallbackLink(post);
        },
      );
    } catch (_) {
      return fallbackLink(post);
    }
  }
}
