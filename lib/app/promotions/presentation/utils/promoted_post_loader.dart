import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_post_by_id_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart' as posts_di;
import 'package:bimobondapp/core/utils/media_utils.dart';

/// Fetches and caches posts for promotion cards and insights.
class PromotedPostLoader {
  PromotedPostLoader._();

  static final _cache = <String, PostEntity>{};
  static final _getPostById = posts_di.sl<GetPostByIdUseCase>();

  static PostEntity? cached(String postId) => _cache[postId];

  static Future<PostEntity?> fetch(String postId) async {
    if (postId.isEmpty) return null;
    final cachedPost = _cache[postId];
    if (cachedPost != null) return cachedPost;

    final result = await _getPostById(postId);
    return result.fold((_) => null, (post) {
      _cache[postId] = post;
      return post;
    });
  }

  static String? coverUrl(PostEntity post) =>
      MediaUtils.resolvePostCoverUrl(post);
}
