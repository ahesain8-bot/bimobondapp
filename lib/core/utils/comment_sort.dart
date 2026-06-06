import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';

int _compareCreatedAtDesc(CommentEntity a, CommentEntity b) {
  final db = DateTime.tryParse(b.createdAt);
  final da = DateTime.tryParse(a.createdAt);
  if (db != null && da != null) return db.compareTo(da);
  return b.createdAt.compareTo(a.createdAt);
}

/// Sorts top-level comments newest first (API + client fallback).
List<CommentEntity> sortCommentsNewest(List<CommentEntity> comments) {
  final sorted = List<CommentEntity>.from(comments);
  sorted.sort(_compareCreatedAtDesc);
  return sorted;
}

/// Sorts top-level comments oldest first.
List<CommentEntity> sortCommentsOldest(List<CommentEntity> comments) {
  final sorted = List<CommentEntity>.from(comments);
  sorted.sort((a, b) => -_compareCreatedAtDesc(a, b));
  return sorted;
}

/// Sorts by like count, then newest as tiebreaker.
List<CommentEntity> sortCommentsTop(List<CommentEntity> comments) {
  final sorted = List<CommentEntity>.from(comments);
  sorted.sort((a, b) {
    final byLikes = b.likeCount.compareTo(a.likeCount);
    if (byLikes != 0) return byLikes;
    return _compareCreatedAtDesc(a, b);
  });
  return sorted;
}

List<CommentEntity> sortCommentsByKey(
  List<CommentEntity> comments,
  String sort,
) {
  switch (sort) {
    case 'oldest':
      return sortCommentsOldest(comments);
    case 'top':
    case 'popular':
      return sortCommentsTop(comments);
    case 'newest':
    default:
      return sortCommentsNewest(comments);
  }
}
