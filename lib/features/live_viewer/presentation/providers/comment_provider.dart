import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/comment_entity.dart';
import 'live_dependencies.dart';

export 'live_dependencies.dart' show commentRepositoryProvider;

/// Standalone comment state for screens that don't use [liveSessionProvider].
class CommentState {
  final List<CommentEntity> comments;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Failure? error;
  final String? cursor;

  const CommentState({
    this.comments = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.cursor,
  });

  CommentState copyWith({
    List<CommentEntity>? comments,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Failure? error,
    String? cursor,
  }) {
    return CommentState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      cursor: cursor ?? this.cursor,
    );
  }
}

class CommentNotifier extends StateNotifier<CommentState> {
  final Ref _ref;
  final String _liveId;

  CommentNotifier(this._ref, this._liveId) : super(const CommentState()) {
    loadComments();
  }

  Future<void> loadComments() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    final result = await _ref.read(commentRepositoryProvider).getComments(
          liveId: _liveId,
          limit: 20,
        );

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure),
      (batch) => state = state.copyWith(
        comments: batch.comments,
        isLoading: false,
        hasMore: batch.hasMore,
        cursor: batch.nextCursor,
      ),
    );
  }

  Future<void> sendComment(String content, {String? replyToUserId}) async {
    if (content.trim().isEmpty) return;
    final result = await _ref.read(commentRepositoryProvider).sendComment(
          liveId: _liveId,
          content: content.trim(),
          replyToUserId: replyToUserId,
        );
    result.fold((_) {}, (comment) {
      state = state.copyWith(comments: [comment, ...state.comments]);
    });
  }
}

final commentProvider = StateNotifierProvider.family<CommentNotifier,
    CommentState, String>((ref, liveId) {
  return CommentNotifier(ref, liveId);
});
