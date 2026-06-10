import 'package:equatable/equatable.dart';

class NotificationActorEntity extends Equatable {
  const NotificationActorEntity({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (username.isNotEmpty) return username;
    return 'Someone';
  }

  @override
  List<Object?> get props => [id, username, fullName, avatarUrl];
}

class NotificationPostEntity extends Equatable {
  const NotificationPostEntity({
    required this.id,
    this.description,
    this.thumbnailUrl,
    this.type,
  });

  final String id;
  final String? description;
  final String? thumbnailUrl;
  final String? type;

  @override
  List<Object?> get props => [id, description, thumbnailUrl, type];
}

class NotificationCommentEntity extends Equatable {
  const NotificationCommentEntity({
    required this.id,
    required this.postId,
    this.content,
  });

  final String id;
  final String postId;
  final String? content;

  @override
  List<Object?> get props => [id, postId, content];
}

class NotificationEntity extends Equatable {
  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.actorId,
    this.title,
    this.body,
    this.data,
    this.postId,
    this.commentId,
    this.actor,
    this.post,
    this.comment,
  });

  final String id;
  final String userId;
  final String type;
  final String? actorId;
  final String? title;
  final String? body;
  final Map<String, dynamic>? data;
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;
  final NotificationActorEntity? actor;
  final NotificationPostEntity? post;
  final NotificationCommentEntity? comment;

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      id: id,
      userId: userId,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      actorId: actorId,
      title: title,
      body: body,
      data: data,
      postId: postId,
      commentId: commentId,
      actor: actor,
      post: post,
      comment: comment,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        actorId,
        title,
        body,
        data,
        postId,
        commentId,
        isRead,
        createdAt,
        actor,
        post,
        comment,
      ];
}

class NotificationsPageEntity extends Equatable {
  const NotificationsPageEntity({
    required this.notifications,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.unreadCount,
  });

  final List<NotificationEntity> notifications;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final int unreadCount;

  bool get hasReachedMax => page >= totalPages;

  @override
  List<Object?> get props =>
      [notifications, page, limit, total, totalPages, unreadCount];
}
