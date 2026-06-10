import 'package:bimobondapp/app/notifications/domain/entities/notification_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class NotificationActorModel extends NotificationActorEntity {
  const NotificationActorModel({
    required super.id,
    required super.username,
    super.fullName,
    super.avatarUrl,
  });

  factory NotificationActorModel.fromJson(Map<String, dynamic> json) {
    final avatarRaw = json['avatarUrl'] ?? json['profilePicture'];
    return NotificationActorModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? json['name']?.toString(),
      avatarUrl: avatarRaw != null
          ? MediaUtils.resolveAbsoluteUrl(avatarRaw.toString())
          : null,
    );
  }
}

class NotificationPostModel extends NotificationPostEntity {
  const NotificationPostModel({
    required super.id,
    super.description,
    super.thumbnailUrl,
    super.type,
  });

  factory NotificationPostModel.fromJson(Map<String, dynamic> json) {
    final thumbRaw = json['thumbnailUrl'] ?? json['thumbnail'];
    return NotificationPostModel(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString(),
      thumbnailUrl: thumbRaw != null
          ? MediaUtils.resolveAbsoluteUrl(thumbRaw.toString())
          : null,
      type: json['type']?.toString(),
    );
  }
}

class NotificationCommentModel extends NotificationCommentEntity {
  const NotificationCommentModel({
    required super.id,
    required super.postId,
    super.content,
  });

  factory NotificationCommentModel.fromJson(Map<String, dynamic> json) {
    return NotificationCommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      content: json['content']?.toString(),
    );
  }
}

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.isRead,
    required super.createdAt,
    super.actorId,
    super.title,
    super.body,
    super.data,
    super.postId,
    super.commentId,
    super.actor,
    super.post,
    super.comment,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actorJson = json['actor'];
    final postJson = json['post'];
    final commentJson = json['comment'];
    final dataRaw = json['data'];

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      actorId: json['actorId']?.toString(),
      type: json['type']?.toString() ?? 'SYSTEM',
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      data: dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : null,
      postId: json['postId']?.toString(),
      commentId: json['commentId']?.toString(),
      isRead: json['isRead'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      actor: actorJson is Map
          ? NotificationActorModel.fromJson(
              Map<String, dynamic>.from(actorJson),
            )
          : null,
      post: postJson is Map
          ? NotificationPostModel.fromJson(Map<String, dynamic>.from(postJson))
          : null,
      comment: commentJson is Map
          ? NotificationCommentModel.fromJson(
              Map<String, dynamic>.from(commentJson),
            )
          : null,
    );
  }
}

class NotificationsPageModel extends NotificationsPageEntity {
  const NotificationsPageModel({
    required super.notifications,
    required super.page,
    required super.limit,
    required super.total,
    required super.totalPages,
    required super.unreadCount,
  });

  factory NotificationsPageModel.fromResponse(
    dynamic body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final root = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final data = root['data'];
    final list = data is List
        ? data
        : (data is Map ? data['data'] : root['data']);
    final raw = list is List ? list : root['notifications'];

    final notifications = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <NotificationModel>[];

    final metaRaw = root['meta'] ?? (data is Map ? data['meta'] : null);
    final meta = metaRaw is Map
        ? Map<String, dynamic>.from(metaRaw)
        : <String, dynamic>{};

    final page = _parseInt(meta['page']) ?? requestedPage;
    final limit = _parseInt(meta['limit']) ?? requestedLimit;
    final total = _parseInt(meta['total']) ?? notifications.length;
    final totalPages = _parseInt(meta['totalPages']) ??
        (notifications.length < requestedLimit ? page : page + 1);
    final unreadCount = _parseInt(meta['unreadCount']) ?? 0;

    return NotificationsPageModel(
      notifications: notifications,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
      unreadCount: unreadCount,
    );
  }
}
