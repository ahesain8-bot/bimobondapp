import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/live_api_client.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
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
          ? meta['hasMore'] == true ||
              (meta['totalPages'] is num &&
                  page < (meta['totalPages'] as num).toInt())
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

      // Backend returns the comment directly or wrapped. A successful HTTP
      // response with no comment object is still a contract failure; do not
      // fabricate a local comment that was never persisted by the server.
      final comment = _commentFromJson(payload, liveId);
      if (comment == null) {
        return const Left(
          ServerFailure('Comment missing from the send response.'),
        );
      }

      // Local echo for instant UI (the server also broadcasts liveComment).
      _append(liveId, comment);
      return Right(comment);
    } catch (e) {
      return Left(ServerFailure('Failed to send comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(
    String commentId, {
    String? liveId,
  }) async {
    try {
      if (liveId != null && liveId.isNotEmpty) {
        await _api.delete(ApiEndpoints.liveCommentById(liveId, commentId));
        // Also remove from cache immediately for optimistic UI.
        final list = _cache[liveId];
        if (list != null) {
          list.removeWhere((c) => c.id == commentId);
          _controllers[liveId]?.add(List.unmodifiable(list));
        }
      }
      // Live id is not known here — fall back to local cache lookup.
      for (final entry in _cache.entries) {
        if (entry.value.any((c) => c.id == commentId)) {
          await _api.delete(ApiEndpoints.liveCommentById(entry.key, commentId));
          final list = List<CommentEntity>.from(entry.value);
          list.removeWhere((c) => c.id == commentId);
          _cache[entry.key] = list;
          _controllers[entry.key]?.add(List.unmodifiable(list));
        }
      }
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to delete comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> pinComment({
    required String liveId,
    required String commentId,
  }) async {
    try {
      await _api.post(ApiEndpoints.liveCommentPin(liveId, commentId));
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to pin comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> unpinComment({
    required String liveId,
    required String commentId,
  }) async {
    try {
      await _api.post(ApiEndpoints.liveCommentUnpin(liveId, commentId));
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to unpin comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    try {
      final liveEntry = _cache.entries
          .cast<MapEntry<String, List<CommentEntity>>?>()
          .firstWhere(
            (entry) => entry!.value.any((comment) => comment.id == commentId),
            orElse: () => null,
          );
      if (liveEntry == null) {
        return Left(
          ServerFailure('Comment $commentId is not available locally'),
        );
      }
      await _api.post(
        '${ApiEndpoints.liveCommentById(liveEntry.key, commentId)}/report',
        body: {'reason': reason, 'details': details},
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Failed to report comment: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markCommentsAsRead(String liveId) async {
    return const Left(
      ServerFailure('Mark-comments-read endpoint is not documented by the API.'),
    );
  }

  @override
  Stream<Either<Failure, List<CommentEntity>>> watchComments(String liveId) {
    _ensureRoom(liveId);
    return _controllers[liveId]!.stream.map(
      (comments) => Right<Failure, List<CommentEntity>>(comments),
    );
  }

  void _ensureRoom(String liveId) {
    if (_controllers.containsKey(liveId)) return;
    _controllers[liveId] = StreamController<List<CommentEntity>>.broadcast();
    final socket = _socket;
    final sub = socket.events.listen((event) {
      if (event is LiveCommentEvent && event.liveId == liveId) {
        final current = List<CommentEntity>.from(
          _cache[liveId] ?? const <CommentEntity>[],
        );
        // Silently drop duplicates (both local echo and socket can deliver).
        if (!current.any((c) => c.id == event.comment.id)) {
          current.add(event.comment);
          final trimmed = current.length > 80
              ? current.sublist(current.length - 80)
              : current;
          _cache[liveId] = trimmed;
          _controllers[liveId]?.add(List.unmodifiable(trimmed));
        }
      } else if (event is LiveCommentDeletedEvent && event.liveId == liveId) {
        final current = List<CommentEntity>.from(
          _cache[liveId] ?? const <CommentEntity>[],
        );
        current.removeWhere((c) => c.id == event.commentId);
        _cache[liveId] = current;
        _controllers[liveId]?.add(List.unmodifiable(current));
      } else if (event is LiveCommentPinnedEvent && event.liveId == liveId) {
        final current = List<CommentEntity>.from(
          _cache[liveId] ?? const <CommentEntity>[],
        );
        final pinned = event.comment.copyWith(isPinned: true);
        var replaced = false;
        for (var i = 0; i < current.length; i++) {
          if (current[i].isPinned) {
            current[i] = current[i].copyWith(isPinned: false);
          }
          if (current[i].id == pinned.id) {
            current[i] = pinned;
            replaced = true;
          }
        }
        if (!replaced) current.insert(0, pinned);
        _cache[liveId] = current;
        _controllers[liveId]?.add(List.unmodifiable(current));
      } else if (event is LiveCommentUnpinnedEvent && event.liveId == liveId) {
        final current = List<CommentEntity>.from(
          _cache[liveId] ?? const <CommentEntity>[],
        );
        for (var i = 0; i < current.length; i++) {
          if (current[i].id == event.commentId) {
            current[i] = current[i].copyWith(isPinned: false);
          }
        }
        _cache[liveId] = current;
        _controllers[liveId]?.add(List.unmodifiable(current));
      }
    });
    _subs[liveId] = sub;
  }

  void _append(String liveId, CommentEntity comment) {
    _ensureRoom(liveId);
    final list = List<CommentEntity>.from(
      _cache[liveId] ?? const <CommentEntity>[],
    );
    list.add(comment);
    final trimmed = list.length > 80 ? list.sublist(list.length - 80) : list;
    _cache[liveId] = trimmed;
    _controllers[liveId]?.add(List.unmodifiable(trimmed));
  }

  CommentEntity? _commentFromJson(dynamic data, String liveId) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    // Try wrapped payload shape { data: {comment...} } or { comment: {...} }
    final inner = map['comment'] ?? map['data'] ?? data;
    final Map<String, dynamic> c;
    if (inner is Map<String, dynamic>) {
      c = inner;
    } else {
      c = map;
    }
    final id = c['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final user = c['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : null;
    final userId = userMap?['id']?.toString() ?? c['userId']?.toString() ?? '';
    final fullName = userMap?['fullName']?.toString();
    final handle =
        userMap?['username']?.toString() ?? c['username']?.toString();
    final username = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : (handle ?? 'User');
    final avatar =
        userMap?['avatarUrl']?.toString() ??
        userMap?['profilePicture']?.toString() ??
        c['avatarUrl']?.toString() ??
        c['userAvatar']?.toString();
    final content = c['content']?.toString() ?? '';
    if (content.isEmpty) return null;

    final gifterLevelRaw = userMap?['gifterLevel'] ?? c['gifterLevel'];
    final gifterLevel = gifterLevelRaw is int
        ? gifterLevelRaw
        : gifterLevelRaw is String
        ? int.tryParse(gifterLevelRaw)
        : null;

    final createdAtRaw = c['createdAt'] ?? c['created_at'] ?? c['timestamp'];
    final DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else if (createdAtRaw is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        createdAtRaw > 1000000000000 ? createdAtRaw : createdAtRaw * 1000,
      );
    } else {
      createdAt = DateTime.now();
    }

    final replyTo =
        c['replyToUserId']?.toString() ??
        c['replyTo']?.toString() ??
        c['replyToUser']?['id']?.toString();
    final isPinned = c['isPinned'] == true || c['pinned'] == true;

    return CommentEntity(
      id: id,
      liveId: liveId,
      userId: userId,
      username: username,
      userAvatar: avatar,
      content: content,
      createdAt: createdAt,
      isPinned: isPinned,
      replyToUserId: replyTo,
      gifterLevel: gifterLevel,
    );
  }

  Future<void> dispose() async {
    for (final sub in _subs.values) {
      await sub.cancel();
    }
    for (final c in _controllers.values) {
      await c.close();
    }
  }
}
