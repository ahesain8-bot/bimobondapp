import 'package:bimobondapp/core/error/failures.dart';
import 'package:bimobondapp/app/posts/domain/entities/comment_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/add_comment_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/delete_comment_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_comments_usecase.dart';
import 'package:bimobondapp/app/posts/domain/usecases/get_replies_usecase.dart';
import 'package:bimobondapp/app/posts/domain/entities/toggle_like_params.dart';
import 'package:bimobondapp/app/posts/domain/usecases/toggle_like_comment_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/comments_state.dart';
import 'package:bimobondapp/app/posts/presentation/utils/comment_thread_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  final GetCommentsUsecase getCommentsUsecase;
  final AddCommentUsecase addCommentUsecase;
  final GetRepliesUsecase getRepliesUsecase;
  final DeleteCommentUsecase deleteCommentUsecase;
  final ToggleLikeCommentUsecase toggleLikeCommentUsecase;

  CommentsBloc({
    required this.getCommentsUsecase,
    required this.addCommentUsecase,
    required this.getRepliesUsecase,
    required this.deleteCommentUsecase,
    required this.toggleLikeCommentUsecase,
  }) : super(CommentsInitial()) {
    on<FetchCommentsRequested>(_onFetchCommentsRequested);
    on<AddCommentRequested>(_onAddCommentRequested);
    on<FetchRepliesRequested>(_onFetchRepliesRequested);
    on<DeleteCommentRequested>(_onDeleteCommentRequested);
    on<ToggleLikeCommentRequested>(_onToggleLikeCommentRequested);
  }

  Future<void> _onFetchCommentsRequested(
    FetchCommentsRequested event,
    Emitter<CommentsState> emit,
  ) async {
    const limit = 20;
    final currentState = state;

    if (event.isRefresh || event.page == 1) {
      emit(CommentsLoading());
    }

    final result = await getCommentsUsecase(
      GetCommentsParams(
        postId: event.postId,
        page: event.page,
        limit: limit,
        sort: event.sort,
      ),
    );
    result.fold(
      (failure) => emit(CommentsFailure(failure.message)),
      (comments) {
        final hasReachedMax = comments.length < limit;

        if (currentState is CommentsLoadSuccess &&
            event.page > 1 &&
            !event.isRefresh) {
          final existingIds =
              currentState.comments.map((c) => c.id).toSet();
          final merged = [
            ...currentState.comments,
            ...comments.where((c) => !existingIds.contains(c.id)),
          ];
          emit(
            CommentsLoadSuccess(
              comments: merged,
              hasReachedMax: hasReachedMax,
              repliesByParentId: currentState.repliesByParentId,
              repliesHasReachedMaxByParentId:
                  currentState.repliesHasReachedMaxByParentId,
            ),
          );
          return;
        }

        final preserveReplies = currentState is CommentsLoadSuccess &&
            event.page > 1 &&
            !event.isRefresh;

        emit(
          CommentsLoadSuccess(
            comments: comments,
            hasReachedMax: hasReachedMax,
            repliesByParentId: preserveReplies
                ? currentState.repliesByParentId
                : const {},
            repliesHasReachedMaxByParentId: preserveReplies
                ? currentState.repliesHasReachedMaxByParentId
                : const {},
          ),
        );
      },
    );
  }

  Future<void> _onAddCommentRequested(
    AddCommentRequested event,
    Emitter<CommentsState> emit,
  ) async {
    final currentState = state;
    final result = await addCommentUsecase(
      AddCommentParams(
        postId: event.postId,
        content: event.content,
        parentId: event.parentId,
      ),
    );
    result.fold((failure) => emit(CommentsFailure(failure.message)), (comment) {
      final threadKey =
          event.threadRootId ?? event.parentId ?? comment.parentId;
      if (currentState is CommentsLoadSuccess && threadKey != null) {
        final updatedReplies = Map<String, List<CommentEntity>>.from(
          currentState.repliesByParentId,
        );
        updatedReplies[threadKey] = mergeThreadReplies(
          updatedReplies[threadKey] ?? const [],
          [comment],
        );

        final updatedComments = currentState.comments.map((c) {
          if (c.id == threadKey) {
            return c.copyWith(replyCount: c.replyCount + 1);
          }
          return c;
        }).toList();

        emit(
          CommentsLoadSuccess(
            comments: updatedComments,
            hasReachedMax: currentState.hasReachedMax,
            repliesByParentId: updatedReplies,
            repliesHasReachedMaxByParentId:
                currentState.repliesHasReachedMaxByParentId,
          ),
        );
        return;
      }
      emit(AddCommentSuccess(comment));
    });
  }

  Future<void> _onFetchRepliesRequested(
    FetchRepliesRequested event,
    Emitter<CommentsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CommentsLoadSuccess) return;

    final result = await getRepliesUsecase(
      GetRepliesParams(
        commentId: event.commentId,
        page: event.page,
        limit: event.limit,
      ),
    );

    Failure? failure;
    List<CommentEntity>? directReplies;
    result.fold(
      (left) => failure = left,
      (right) => directReplies = right,
    );
    if (failure != null) {
      emit(CommentsFailure(failure!.message));
      return;
    }

    final flattened = await _flattenReplyThread(directReplies ?? const []);
    final updatedReplies = Map<String, List<CommentEntity>>.from(
      currentState.repliesByParentId,
    );
    final existing = event.page > 1
        ? List<CommentEntity>.from(
            updatedReplies[event.commentId] ?? const [],
          )
        : <CommentEntity>[];
    updatedReplies[event.commentId] = mergeThreadReplies(
      existing,
      flattened,
    );

    final updatedHasReachedMax = Map<String, bool>.from(
      currentState.repliesHasReachedMaxByParentId,
    );
    updatedHasReachedMax[event.commentId] =
        (directReplies?.length ?? 0) < event.limit;

    emit(
      CommentsLoadSuccess(
        comments: currentState.comments,
        hasReachedMax: currentState.hasReachedMax,
        repliesByParentId: updatedReplies,
        repliesHasReachedMaxByParentId: updatedHasReachedMax,
      ),
    );
  }

  Future<List<CommentEntity>> _flattenReplyThread(
    List<CommentEntity> directReplies,
  ) async {
    final byId = <String, CommentEntity>{
      for (final reply in directReplies) reply.id: reply,
    };

    for (final reply in directReplies) {
      if (reply.replyCount <= 0) continue;

      final nestedResult = await getRepliesUsecase(
        GetRepliesParams(commentId: reply.id, page: 1, limit: 100),
      );
      nestedResult.fold((_) {}, (nested) {
        for (final child in nested) {
          byId[child.id] = child;
        }
      });
    }

    return sortCommentsOldestFirst(byId.values.toList());
  }

  Future<void> _onDeleteCommentRequested(
    DeleteCommentRequested event,
    Emitter<CommentsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CommentsLoadSuccess) return;

    final result = await deleteCommentUsecase(event.commentId);
    result.fold((failure) => emit(CommentsFailure(failure.message)), (_) {
      emit(
        DeleteCommentSuccess(event.commentId, parentId: event.parentId),
      );
      emit(_applyDelete(currentState, event.commentId, event.parentId));
    });
  }

  CommentsLoadSuccess _applyDelete(
    CommentsLoadSuccess state,
    String commentId,
    String? parentId,
  ) {
    if (parentId != null) {
      final updatedReplies = Map<String, List<CommentEntity>>.from(
        state.repliesByParentId,
      );
      final replies = List<CommentEntity>.from(
        updatedReplies[parentId] ?? const [],
      )..removeWhere((reply) => reply.id == commentId);
      updatedReplies[parentId] = replies;

      final updatedComments = state.comments.map((comment) {
        if (comment.id == parentId && comment.replyCount > 0) {
          return comment.copyWith(replyCount: comment.replyCount - 1);
        }
        return comment;
      }).toList();

      return CommentsLoadSuccess(
        comments: updatedComments,
        hasReachedMax: state.hasReachedMax,
        repliesByParentId: updatedReplies,
        repliesHasReachedMaxByParentId: state.repliesHasReachedMaxByParentId,
      );
    }

    final updatedComments = state.comments
        .where((comment) => comment.id != commentId)
        .toList();

    final updatedReplies = Map<String, List<CommentEntity>>.from(
      state.repliesByParentId,
    )..remove(commentId);

    return CommentsLoadSuccess(
      comments: updatedComments,
      hasReachedMax: state.hasReachedMax,
      repliesByParentId: updatedReplies,
      repliesHasReachedMaxByParentId: state.repliesHasReachedMaxByParentId,
    );
  }

  CommentEntity _toggleLike(CommentEntity comment) {
    final isLiked = !comment.isLiked;
    return comment.copyWith(
      isLiked: isLiked,
      likeCount: isLiked ? comment.likeCount + 1 : comment.likeCount - 1,
    );
  }

  CommentsLoadSuccess _applyLikeUpdate(
    CommentsLoadSuccess currentState,
    String commentId,
  ) {
    final updatedComments = currentState.comments.map((comment) {
      if (comment.id == commentId) return _toggleLike(comment);
      return comment;
    }).toList();

    final updatedReplies = currentState.repliesByParentId.map((
      parentId,
      replies,
    ) {
      return MapEntry(
        parentId,
        replies
            .map((reply) => reply.id == commentId ? _toggleLike(reply) : reply)
            .toList(),
      );
    });

    return CommentsLoadSuccess(
      comments: updatedComments,
      hasReachedMax: currentState.hasReachedMax,
      repliesByParentId: updatedReplies,
      repliesHasReachedMaxByParentId:
          currentState.repliesHasReachedMaxByParentId,
    );
  }

  Future<void> _onToggleLikeCommentRequested(
    ToggleLikeCommentRequested event,
    Emitter<CommentsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! CommentsLoadSuccess) return;

    final optimisticState = _applyLikeUpdate(currentState, event.commentId);
    emit(optimisticState);

    final result = await toggleLikeCommentUsecase(
      ToggleLikeParams(id: event.commentId, liked: event.liked),
    );
    result.fold((failure) => emit(currentState), (_) {});
  }
}
