import 'package:equatable/equatable.dart';
import 'comment_entity.dart';
import 'gift_entity.dart';

/// Socket event types matching the backend contract.
enum SocketEventType {
  liveComment,
  liveCommentDeleted,
  liveCommentPinned,
  liveCommentUnpinned,
  liveModeration,
  liveGift,
  liveLike,
  liveViewers,
  liveEnded,
  userJoined,
  reconnecting,
  reconnected,
  networkLost,
}

/// Base sealed-style event emitted by the fake / real socket layer.
abstract class SocketEvent extends Equatable {
  final SocketEventType type;
  final String liveId;
  final DateTime timestamp;

  const SocketEvent({
    required this.type,
    required this.liveId,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [type, liveId, timestamp];
}

class LiveCommentEvent extends SocketEvent {
  final CommentEntity comment;

  const LiveCommentEvent({
    required super.liveId,
    required this.comment,
    required super.timestamp,
  }) : super(type: SocketEventType.liveComment);

  @override
  List<Object?> get props => [...super.props, comment];
}

class LiveCommentDeletedEvent extends SocketEvent {
  final String commentId;

  const LiveCommentDeletedEvent({
    required super.liveId,
    required this.commentId,
    required super.timestamp,
  }) : super(type: SocketEventType.liveCommentDeleted);

  @override
  List<Object?> get props => [...super.props, commentId];
}

class LiveCommentPinnedEvent extends SocketEvent {
  final CommentEntity comment;

  const LiveCommentPinnedEvent({
    required super.liveId,
    required this.comment,
    required super.timestamp,
  }) : super(type: SocketEventType.liveCommentPinned);

  @override
  List<Object?> get props => [...super.props, comment];
}

class LiveCommentUnpinnedEvent extends SocketEvent {
  final String commentId;

  const LiveCommentUnpinnedEvent({
    required super.liveId,
    required this.commentId,
    required super.timestamp,
  }) : super(type: SocketEventType.liveCommentUnpinned);

  @override
  List<Object?> get props => [...super.props, commentId];
}

class LiveModerationEvent extends SocketEvent {
  final String moderationType;
  final String? userId;
  final String? reason;

  const LiveModerationEvent({
    required super.liveId,
    required this.moderationType,
    this.userId,
    this.reason,
    required super.timestamp,
  }) : super(type: SocketEventType.liveModeration);

  @override
  List<Object?> get props => [...super.props, moderationType, userId, reason];
}

class LiveGiftEvent extends SocketEvent {
  final GiftSentEntity gift;

  const LiveGiftEvent({
    required super.liveId,
    required this.gift,
    required super.timestamp,
  }) : super(type: SocketEventType.liveGift);

  @override
  List<Object?> get props => [...super.props, gift];
}

class LiveLikeEvent extends SocketEvent {
  final int likeCount;
  final int delta;
  final String? userId;

  const LiveLikeEvent({
    required super.liveId,
    required this.likeCount,
    this.delta = 1,
    this.userId,
    required super.timestamp,
  }) : super(type: SocketEventType.liveLike);

  @override
  List<Object?> get props => [...super.props, likeCount, delta, userId];
}

class LiveViewersEvent extends SocketEvent {
  final int viewerCount;
  final List<String> topViewerAvatars;

  const LiveViewersEvent({
    required super.liveId,
    required this.viewerCount,
    this.topViewerAvatars = const [],
    required super.timestamp,
  }) : super(type: SocketEventType.liveViewers);

  @override
  List<Object?> get props => [...super.props, viewerCount, topViewerAvatars];
}

class LiveEndedEvent extends SocketEvent {
  final String reason;

  const LiveEndedEvent({
    required super.liveId,
    this.reason = 'Host ended the live',
    required super.timestamp,
  }) : super(type: SocketEventType.liveEnded);

  @override
  List<Object?> get props => [...super.props, reason];
}

class UserJoinedEvent extends SocketEvent {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int? viewerCount;

  const UserJoinedEvent({
    required super.liveId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.viewerCount,
    required super.timestamp,
  }) : super(type: SocketEventType.userJoined);

  @override
  List<Object?> get props => [
    ...super.props,
    userId,
    username,
    avatarUrl,
    viewerCount,
  ];
}

class NetworkLostEvent extends SocketEvent {
  const NetworkLostEvent({required super.liveId, required super.timestamp})
    : super(type: SocketEventType.networkLost);
}

class ReconnectingEvent extends SocketEvent {
  final int attempt;

  const ReconnectingEvent({
    required super.liveId,
    required this.attempt,
    required super.timestamp,
  }) : super(type: SocketEventType.reconnecting);

  @override
  List<Object?> get props => [...super.props, attempt];
}

class ReconnectedEvent extends SocketEvent {
  const ReconnectedEvent({required super.liveId, required super.timestamp})
    : super(type: SocketEventType.reconnected);
}
