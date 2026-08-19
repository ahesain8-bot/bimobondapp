import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/entities/socket_event.dart';
import '../../domain/repositories/comment_repository.dart';
import '../services/fake_socket_service.dart' show SocketService;

/// Real [CommentRepository] backed by the backend:
/// - `GET  /lives/:id/comments`   → history (pinned first)
/// - `POST /lives/:id/comments`   → send (emits `liveComment` on the socket)
/// - `DELETE /lives/:id/comments/:commentId` → host/mod delete
/// - Socket `liveComment` events → real-time stream
class RealCommentRepository implements CommentRepository {
  RealCommentRepository({
    required LiveApiClient apiClient,
    required SocketService socket,
  }) : _api = apiClient,
       _socket = socket;

  final LiveApiClient _api;
  final SocketService _socket;

  final Map<String, StreamController<List<CommentEntity>>> _controllers = {};
  final Map<String, StreamSubscription<SocketEvent>> _subs = {};
  final Map<String, List<CommentEntity>> _cache = {};

  @override
  Future<Either<Failure, CommentBatch>> getComments({
    required String liveId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final page = int.tryParse(cursor ?? '') ?? 1;
      final payload = await _api.get(
        ApiEndpoints.liveComments(liveId),
        query: {'page': '$page', 'limit': '$limit'},
      );

      final data = payload['data'];
      final comments = <CommentEntity>[];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final c = _commentFromJson(item, liveId);
            if (c != null) comments.add(c);
          }
        }
      }

      final pinned = payload['pinnedComment'];
      if (pinned is Map<String, dynamic>) {
        final p = _commentFromJson(pinned, liveId);
        if (p != null) {
          comments.removeWhere((c) => c.id == p.id);
          comments.insert(0, p.copyWith(isPinned: true));
        }
      }

      _ensureRoom(liveId);
      _cache[liveId] = List<CommentEntity>.from(comments);

      final meta = payload['meta'];
      final hasMore = meta is Map<String, dynamic>
          ? (meta['hasMore'] == true || meta['totalPages'] is int)
          : comments.length >= limit;

      return Right(
        CommentBatch(
          comments: comments,
          hasMore: hasMore,
          nextCursor: hasMore ? '${page + 1}' : null,
        ),
      );
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
    try {
      final payload = await _api.post(
        ApiEndpoints.liveComments(liveId),
        body: {'content': content},
      );

      // Backend returns the comment directly or wrapped.
      final comment =
          _commentFromJson(payload, liveId) ??
          CommentEntity(
            id: 'c_${DateTime.now().microsecondsSinceEpoch}',
            liveId: liveId,
            userId: '',
            username: 'You',
            content: content,
            createdAt: DateTime.now(),
            replyToUserId: replyToUserId,
          );

      // Local echo for instant UI (the server also broadcasts liveComment).
      _append(liveId, comment);
      return Right(comment);
    } catch (e) {
      return Left(ServerFailure('Failed to send comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      // Live id is not known here — fall back to local cache lookup.
      for (final entry in _cache.entries) {
        if (entry.value.any((c) => c.id == commentId)) {
          await _api.delete(ApiEndpoints.liveCommentById(entry.key, commentId));
          return const Right(null);
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    // No dedicated endpoint in mobile-api.md — treat as no-op success.
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
    _cache.putIfAbsent(liveId, () => []);
    _controllers.putIfAbsent(
      liveId,
      () => StreamController<List<CommentEntity>>.broadcast(),
    );
    _subs.putIfAbsent(liveId, () {
      return _socket.events.listen((event) {
        if (event.liveId != liveId) return;
        if (event is LiveCommentEvent) {
          _append(liveId, event.comment, fromSocket: true);
        } else if (event is LiveCommentDeletedEvent) {
          _remove(liveId, event.commentId);
        } else if (event is LiveCommentPinnedEvent) {
          _setPinned(liveId, event.comment);
        } else if (event is LiveCommentUnpinnedEvent) {
          _clearPinned(liveId, event.commentId);
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
    final list = _cache.putIfAbsent(liveId, () => []);
    if (fromSocket && list.any((c) => c.id == comment.id)) return;
    list.add(comment);
    if (list.length > 120) {
      list.removeRange(0, list.length - 120);
    }
    _controllers[liveId]?.add(List.unmodifiable(list));
  }

  void _remove(String liveId, String commentId) {
    final list = _cache[liveId];
    if (list == null) return;
    list.removeWhere((c) => c.id == commentId);
    _controllers[liveId]?.add(List.unmodifiable(list));
  }

  void _setPinned(String liveId, CommentEntity comment) {
    final list = _cache.putIfAbsent(liveId, () => []);
    final pinned = comment.copyWith(isPinned: true);
    list.removeWhere((c) => c.id == pinned.id);
    for (var i = 0; i < list.length; i++) {
      if (list[i].isPinned) {
        list[i] = list[i].copyWith(isPinned: false);
      }
    }
    list.insert(0, pinned);
    _controllers[liveId]?.add(List.unmodifiable(list));
  }

  void _clearPinned(String liveId, String commentId) {
    final list = _cache[liveId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == commentId || list[i].isPinned) {
        list[i] = list[i].copyWith(isPinned: false);
      }
    }
    _controllers[liveId]?.add(List.unmodifiable(list));
  }

  CommentEntity? _commentFromJson(Map<String, dynamic> json, String liveId) {
    final user = json['user'];
    final userMap = user is Map<String, dynamic>
        ? user
        : (user is Map ? Map<String, dynamic>.from(user) : null);

    final content =
        json['content']?.toString() ?? json['text']?.toString() ?? '';
    if (content.isEmpty && json['id'] == null) return null;

    return CommentEntity(
      id:
          json['id']?.toString() ??
          'c_${DateTime.now().microsecondsSinceEpoch}',
      liveId: json['liveId']?.toString() ?? liveId,
      userId: userMap?['id']?.toString() ?? json['userId']?.toString() ?? '',
      username:
          userMap?['username']?.toString() ??
          userMap?['fullName']?.toString() ??
          'User',
      userAvatar: userMap?['avatarUrl']?.toString(),
      content: content,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      replyToUserId: json['replyToUserId']?.toString(),
      gifterLevel: _asInt(userMap?['gifterLevel']),
      isVerified: userMap?['isVerified'] == true,
      isPinned: json['isPinned'] == true || json['pinned'] == true,
      metadata: json['isPinned'] == true || json['pinned'] == true
          ? const {'pinned': true}
          : null,
    );
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
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
