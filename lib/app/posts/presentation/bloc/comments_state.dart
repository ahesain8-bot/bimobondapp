import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:equatable/equatable.dart';

abstract class CommentsState extends Equatable {
  const CommentsState();

  @override
  List<Object?> get props => [];
}

class CommentsInitial extends CommentsState {}

class CommentsLoading extends CommentsState {}

class CommentsLoadSuccess extends CommentsState {
  final List<CommentEntity> comments;
  final bool hasReachedMax;
  final Map<String, List<CommentEntity>> repliesByParentId;
  final Map<String, bool> repliesHasReachedMaxByParentId;

  const CommentsLoadSuccess({
    required this.comments,
    this.hasReachedMax = false,
    this.repliesByParentId = const {},
    this.repliesHasReachedMaxByParentId = const {},
  });

  @override
  List<Object?> get props => [
        comments,
        hasReachedMax,
        repliesByParentId,
        repliesHasReachedMaxByParentId,
      ];
}

class CommentsFailure extends CommentsState {
  final String message;

  const CommentsFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class AddCommentSuccess extends CommentsState {
  final CommentEntity comment;

  const AddCommentSuccess(this.comment);

  @override
  List<Object?> get props => [comment];
}

class ToggleLikeCommentSuccess extends CommentsState {
  final String commentId;

  const ToggleLikeCommentSuccess(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class DeleteCommentSuccess extends CommentsState {
  final String commentId;

  const DeleteCommentSuccess(this.commentId);

  @override
  List<Object?> get props => [commentId];
}
