import 'dart:async';
import 'dart:math';

import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../../domain/repositories/comment_repository.dart';
import '../services/fake_socket_service.dart';

class FakeCommentRepository implements CommentRepository {
  final SocketService _socket;
  final Random _random = Random();
  final Map<String, List<CommentEntity>> _comments = {};
  final Map<String, StreamController<List<CommentEntity>>> _controllers = {};
  final Map<String, StreamSubscription<SocketEvent>> _subs = {};

  FakeCommentRepository(this._socket);

  @override
  Future<Either<Failure, CommentBatch>> getComments({
    required String liveId,
    String? cursor,
    int limit = 20,
  }) async {
    // GET /comments
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      _ensureRoom(liveId);
      final all = _comments[liveId]!;
      if (all.isEmpty) {
        final seed = List.generate(
          8,
          (_) => _seedComment(liveId),
        );
        all.addAll(seed);
      }
      final slice = all.length > limit
          ? all.sublist(all.length - limit)
          : List<CommentEntity>.from(all);
      return Right(CommentBatch(
        comments: slice.reversed.toList(),
        hasMore: all.length > limit,
        nextCursor: all.length > limit ? 'cursor_${all.length}' : null,
      ));
    } catch (e) {
      return Left(ServerFailure('Failed to fetch comments: $e'));
    }
  }

  @override
  Future<Either<Failure, CommentEntity>> sendComment({
    required String liveId,
    required String content,
    String? replyToUserId,
  }) async {
    // POST /comments
    await Future.delayed(const Duration(milliseconds: 220));
    try {
      final comment = CommentEntity(
        id: 'comment_${DateTime.now().microsecondsSinceEpoch}',
        liveId: liveId,
        userId: 'current_user',
        username: 'You',
        userAvatar: 'https://i.pravatar.cc/150?u=me',
        content: content,
        createdAt: DateTime.now(),
        replyToUserId: replyToUserId,
      );
      _append(liveId, comment);
      await _socket.emitComment(comment);
      return Right(comment);
    } catch (e) {
      return Left(ServerFailure('Failed to send comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(null);
  }

  @override
  Stream<Either<Failure, List<CommentEntity>>> watchComments(String liveId) {
    _ensureRoom(liveId);
    return _controllers[liveId]!.stream.map(Right.new);
  }

  @override
  Future<Either<Failure, void>> markCommentsAsRead(String liveId) async {
    return const Right(null);
  }

  void _ensureRoom(String liveId) {
    _comments.putIfAbsent(liveId, () => []);
    _controllers.putIfAbsent(
      liveId,
      () => StreamController<List<CommentEntity>>.broadcast(),
    );
    _subs.putIfAbsent(liveId, () {
      return _socket.events.listen((event) {
        if (event.liveId != liveId) return;
        if (event is LiveCommentEvent) {
          _append(liveId, event.comment, fromSocket: true);
        } else if (event is UserJoinedEvent) {
          final joinComment = CommentEntity(
            id: 'join_${event.userId}_${event.timestamp.microsecondsSinceEpoch}',
            liveId: liveId,
            userId: event.userId,
            username: event.username,
            userAvatar: event.avatarUrl,
            content: 'joined',
            createdAt: event.timestamp,
            metadata: const {'type': 'join'},
          );
          _append(liveId, joinComment, fromSocket: true);
        }
      });
    });
  }

  void _append(
    String liveId,
    CommentEntity comment, {
    bool fromSocket = false,
  }) {
    final list = _comments.putIfAbsent(liveId, () => []);
    // Avoid duplicate from echo when we already appended locally.
    if (fromSocket && list.any((c) => c.id == comment.id)) return;
    list.add(comment);
    if (list.length > 120) {
      list.removeRange(0, list.length - 120);
    }
    _controllers[liveId]?.add(List.unmodifiable(list));
  }

  CommentEntity _seedComment(String liveId) {
    const names = ['Alex', 'Sam', 'Jordan', 'Casey', 'Riley', 'Avery'];
    const msgs = [
      'Hello! 👋',
      'Amazing! 🔥',
      'Love this! ❤️',
      'So cool! ✨',
      'Hi everyone!',
      'Big fan! 🎉',
    ];
    final username = names[_random.nextInt(names.length)];
    return CommentEntity(
      id: 'seed_${_random.nextInt(999999)}',
      liveId: liveId,
      userId: 'user_${_random.nextInt(9999)}',
      username: username,
      userAvatar: 'https://i.pravatar.cc/150?u=$username',
      content: msgs[_random.nextInt(msgs.length)],
      createdAt: DateTime.now().subtract(Duration(seconds: _random.nextInt(90))),
    );
  }

  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    for (final c in _controllers.values) {
      c.close();
    }
  }
}
