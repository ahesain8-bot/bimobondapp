import 'package:equatable/equatable.dart';

class CommentEntity extends Equatable {
  final String id;
  final String liveId;
  final String userId;
  final String username;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;
  final String? replyToUserId;
  final String? replyToUsername;
  final List<String>? mentions;
  final Map<String, dynamic>? metadata;
  final int? gifterLevel;
  final bool isVerified;
  final bool isPinned;

  const CommentEntity({
    required this.id,
    required this.liveId,
    required this.userId,
    required this.username,
    this.userAvatar,
    required this.content,
    required this.createdAt,
    this.replyToUserId,
    this.replyToUsername,
    this.mentions,
    this.metadata,
    this.gifterLevel,
    this.isVerified = false,
    this.isPinned = false,
  });

  CommentEntity copyWith({
    String? id,
    String? liveId,
    String? userId,
    String? username,
    String? userAvatar,
    String? content,
    DateTime? createdAt,
    String? replyToUserId,
    String? replyToUsername,
    List<String>? mentions,
    Map<String, dynamic>? metadata,
    int? gifterLevel,
    bool? isVerified,
    bool? isPinned,
  }) {
    return CommentEntity(
      id: id ?? this.id,
      liveId: liveId ?? this.liveId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatar: userAvatar ?? this.userAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      replyToUsername: replyToUsername ?? this.replyToUsername,
      mentions: mentions ?? this.mentions,
      metadata: metadata ?? this.metadata,
      gifterLevel: gifterLevel ?? this.gifterLevel,
      isVerified: isVerified ?? this.isVerified,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [
    id,
    liveId,
    userId,
    username,
    userAvatar,
    content,
    createdAt,
    replyToUserId,
    replyToUsername,
    mentions,
    metadata,
    gifterLevel,
    isVerified,
    isPinned,
  ];
}

class CommentBatch {
  final List<CommentEntity> comments;
  final bool hasMore;
  final String? nextCursor;

  const CommentBatch({
    required this.comments,
    this.hasMore = false,
    this.nextCursor,
  });
}
