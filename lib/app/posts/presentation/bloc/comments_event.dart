import 'package:equatable/equatable.dart';

abstract class CommentsEvent extends Equatable {
  const CommentsEvent();

  @override
  List<Object?> get props => [];
}

class FetchCommentsRequested extends CommentsEvent {
  final String postId;
  final int page;
  final bool isRefresh;
  final String sort;

  const FetchCommentsRequested({
    required this.postId,
    this.page = 1,
    this.isRefresh = false,
    this.sort = 'newest',
  });

  @override
  List<Object?> get props => [postId, page, isRefresh, sort];
}

class AddCommentRequested extends CommentsEvent {
  final String postId;
  final String content;
  final String? parentId;

  /// Top-level comment id for grouping nested replies in the UI thread.
  final String? threadRootId;

  const AddCommentRequested({
    required this.postId,
    required this.content,
    this.parentId,
    this.threadRootId,
  });

  @override
  List<Object?> get props => [postId, content, parentId, threadRootId];
}

class FetchRepliesRequested extends CommentsEvent {
  final String commentId;
  final int page;
  final int limit;

  const FetchRepliesRequested({
    required this.commentId,
    this.page = 1,
    this.limit = 20,
  });

  @override
  List<Object?> get props => [commentId, page, limit];
}

class ToggleLikeCommentRequested extends CommentsEvent {
  final String commentId;
  final bool liked;

  const ToggleLikeCommentRequested(this.commentId, {required this.liked});

  @override
  List<Object?> get props => [commentId, liked];
}

class DeleteCommentRequested extends CommentsEvent {
  final String commentId;
  final String? parentId;

  const DeleteCommentRequested(this.commentId, {this.parentId});

  @override
  List<Object?> get props => [commentId, parentId];
}
