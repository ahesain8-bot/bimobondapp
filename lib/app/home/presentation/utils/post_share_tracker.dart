import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_share_result.dart';
import 'package:bimobondapp/app/posts/domain/usecases/share_post_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/core/services/post_share_refresh_bus.dart';
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
    final result = await trackAndResolve(post, channel: channel);
    final url = result?.shareUrl;
    if (url != null && url.isNotEmpty) return url;
    return fallbackLink(post);
  }

  /// Same call, but hands back the whole server reply instead of just the
  /// link. The share counter needs `shareCount`, which the link-only variant
  /// above has to throw away to keep its signature.
  static Future<PostShareResult?> trackAndResolve(
    PostEntity post, {
    String channel = 'EXTERNAL',
  }) async {
    try {
      final result = await posts_di.sl<SharePostUseCase>()(
        SharePostParams(postId: post.id, channel: channel),
      );
      return result.fold((_) => null, (share) {
        // One place to announce it: every share path funnels through here.
        PostShareRefreshBus.instance.notifyPostShared(
          post.id,
          shareCount: share.shareCount,
        );
        return share;
      });
    } catch (_) {
      return null;
    }
  }
}
