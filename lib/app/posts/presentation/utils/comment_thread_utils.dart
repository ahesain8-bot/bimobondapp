import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';

int compareCommentsOldestFirst(CommentEntity a, CommentEntity b) {
  final da = DateTime.tryParse(a.createdAt);
  final db = DateTime.tryParse(b.createdAt);
  if (da != null && db != null) return da.compareTo(db);
  return a.createdAt.compareTo(b.createdAt);
}

List<CommentEntity> sortCommentsOldestFirst(List<CommentEntity> comments) {
  final sorted = List<CommentEntity>.from(comments);
  sorted.sort(compareCommentsOldestFirst);
  return sorted;
}

List<CommentEntity> mergeThreadReplies(
  List<CommentEntity> existing,
  Iterable<CommentEntity> incoming,
) {
  final byId = <String, CommentEntity>{
    for (final comment in existing) comment.id: comment,
  };
  for (final comment in incoming) {
    byId[comment.id] = comment;
  }
  return sortCommentsOldestFirst(byId.values.toList());
}

int countDirectReplies(
  List<CommentEntity> loadedReplies,
  String parentCommentId,
) {
  return loadedReplies
      .where((reply) => reply.parentId == parentCommentId)
      .length;
}

bool hasMoreThreadReplies({
  required CommentEntity parent,
  required List<CommentEntity> loadedReplies,
  required Map<String, bool> reachedMaxByParentId,
}) {
  final directCount = countDirectReplies(loadedReplies, parent.id);
  if (parent.replyCount <= 0 || directCount >= parent.replyCount) {
    return false;
  }
  if (loadedReplies.isEmpty) return false;

  final reachedMax = reachedMaxByParentId[parent.id];
  if (reachedMax == true) return false;
  return reachedMax == false || directCount < parent.replyCount;
}
