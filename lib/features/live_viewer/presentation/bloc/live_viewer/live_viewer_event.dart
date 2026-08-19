import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/comment_entity.dart';
import '../../../domain/entities/gift_entity.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/entities/live_session_entity.dart';

abstract class LiveViewerEvent extends Equatable {
  const LiveViewerEvent();

  @override
  List<Object?> get props => const [];
}

class LiveViewerActivated extends LiveViewerEvent {
  final LiveEntity live;

  const LiveViewerActivated(this.live);

  @override
  List<Object?> get props => [live];
}

class LiveViewerDeactivated extends LiveViewerEvent {
  const LiveViewerDeactivated();
}

class LiveViewerRetryRequested extends LiveViewerEvent {
  const LiveViewerRetryRequested();
}

class LiveViewerCommentSent extends LiveViewerEvent {
  final String content;

  const LiveViewerCommentSent(this.content);

  @override
  List<Object?> get props => [content];
}

class LiveViewerLiked extends LiveViewerEvent {
  final int burst;

  const LiveViewerLiked({this.burst = 1});

  @override
  List<Object?> get props => [burst];
}

class LiveViewerGiftSent extends LiveViewerEvent {
  final GiftEntity gift;
  final int quantity;

  const LiveViewerGiftSent(this.gift, {this.quantity = 1});

  @override
  List<Object?> get props => [gift, quantity];
}

class LiveViewerFollowToggled extends LiveViewerEvent {
  const LiveViewerFollowToggled();
}

class LiveViewerHeartBurstConsumed extends LiveViewerEvent {
  const LiveViewerHeartBurstConsumed();
}

class LiveViewerGiftAnimationCleared extends LiveViewerEvent {
  const LiveViewerGiftAnimationCleared();
}

class LiveViewerModerationBannerConsumed extends LiveViewerEvent {
  const LiveViewerModerationBannerConsumed();
}

class LiveViewerSocketEventReceived extends LiveViewerEvent {
  final dynamic event;

  const LiveViewerSocketEventReceived(this.event);

  @override
  List<Object?> get props => [identityHashCode(event)];
}
