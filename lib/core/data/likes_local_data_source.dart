import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class LikesLocalDataSource {
  bool resolvePostLiked(String userId, String postId, bool apiIsLiked);
  bool resolveCommentLiked(String userId, String commentId, bool apiIsLiked);

  Future<void> setPostLiked(String userId, String postId, bool liked);
  Future<void> setCommentLiked(String userId, String commentId, bool liked);

  Future<void> clearForUser(String userId);
  Future<void> clearAll();

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
}

class LikesLocalDataSourceImpl implements LikesLocalDataSource {
  final SharedPreferences sharedPreferences;

  LikesLocalDataSourceImpl({required this.sharedPreferences});

  @override
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static String _likedPostsKey(String userId) => 'liked_posts_$userId';
  static String _unlikedPostsKey(String userId) => 'unliked_posts_$userId';
  static String _likedCommentsKey(String userId) => 'liked_comments_$userId';
  static String _unlikedCommentsKey(String userId) => 'unliked_comments_$userId';

  Set<String> _readSet(String key) =>
      sharedPreferences.getStringList(key)?.toSet() ?? {};

  Future<void> _writeSet(String key, Set<String> values) async {
    await sharedPreferences.setStringList(key, values.toList());
  }

  bool _resolveLiked(
    String userId,
    String id,
    bool apiIsLiked,
    String likedKey,
    String unlikedKey,
  ) {
    final unliked = _readSet(unlikedKey);
    if (unliked.contains(id)) return false;
    final liked = _readSet(likedKey);
    if (liked.contains(id)) return true;
    return apiIsLiked;
  }

  Future<void> _setLiked(
    String userId,
    String id,
    bool liked,
    String likedKey,
    String unlikedKey,
  ) async {
    final likedSet = _readSet(likedKey);
    final unlikedSet = _readSet(unlikedKey);
    if (liked) {
      likedSet.add(id);
      unlikedSet.remove(id);
    } else {
      unlikedSet.add(id);
      likedSet.remove(id);
    }
    await _writeSet(likedKey, likedSet);
    await _writeSet(unlikedKey, unlikedSet);
  }

  @override
  bool resolvePostLiked(String userId, String postId, bool apiIsLiked) {
    return _resolveLiked(
      userId,
      postId,
      apiIsLiked,
      _likedPostsKey(userId),
      _unlikedPostsKey(userId),
    );
  }

  @override
  bool resolveCommentLiked(String userId, String commentId, bool apiIsLiked) {
    return _resolveLiked(
      userId,
      commentId,
      apiIsLiked,
      _likedCommentsKey(userId),
      _unlikedCommentsKey(userId),
    );
  }

  @override
  Future<void> setPostLiked(String userId, String postId, bool liked) {
    return _setLiked(
      userId,
      postId,
      liked,
      _likedPostsKey(userId),
      _unlikedPostsKey(userId),
    );
  }

  @override
  Future<void> setCommentLiked(String userId, String commentId, bool liked) {
    return _setLiked(
      userId,
      commentId,
      liked,
      _likedCommentsKey(userId),
      _unlikedCommentsKey(userId),
    );
  }

  @override
  Future<void> clearForUser(String userId) async {
    await Future.wait([
      sharedPreferences.remove(_likedPostsKey(userId)),
      sharedPreferences.remove(_unlikedPostsKey(userId)),
      sharedPreferences.remove(_likedCommentsKey(userId)),
      sharedPreferences.remove(_unlikedCommentsKey(userId)),
    ]);
  }

  @override
  Future<void> clearAll() async {
    final keys = sharedPreferences
        .getKeys()
        .where(
          (key) =>
              key.startsWith('liked_posts_') ||
              key.startsWith('unliked_posts_') ||
              key.startsWith('liked_comments_') ||
              key.startsWith('unliked_comments_'),
        )
        .toList();
    await Future.wait(keys.map(sharedPreferences.remove));
  }
}
