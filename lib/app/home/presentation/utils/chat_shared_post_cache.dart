import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';

/// In-memory cache for posts/stories loaded for chat message previews.
class ChatSharedPostCache {
  ChatSharedPostCache._();

  static final Map<String, PostEntity> _posts = {};

  static PostEntity? get(String postId) => _posts[postId];

  static void put(PostEntity post) => _posts[post.id] = post;
}
