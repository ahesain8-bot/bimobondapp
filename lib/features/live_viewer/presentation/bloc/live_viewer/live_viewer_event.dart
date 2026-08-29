import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../data/services/fake_livekit_service.dart';

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

class LiveViewerGiftBalanceRefreshRequested extends LiveViewerEvent {
  const LiveViewerGiftBalanceRefreshRequested();
}

class LiveViewerGiftComboReceived extends LiveViewerEvent {
  final GiftComboPayload payload;

  const LiveViewerGiftComboReceived(this.payload);

  @override
  List<Object?> get props => [payload];
}

/// The gift layer presented [payload]; release it so remounting the layer
/// cannot replay an animation the viewer has already seen.
class LiveViewerGiftComboConsumed extends LiveViewerEvent {
  final GiftComboPayload payload;

  const LiveViewerGiftComboConsumed(this.payload);

  @override
  List<Object?> get props => [payload];
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

class LiveViewerJoinSuccessConsumed extends LiveViewerEvent {
  const LiveViewerJoinSuccessConsumed();
}

/// Debounced REST refresh for both sides of an active PK battle.
class LiveViewerBattleSupportersRefreshRequested extends LiveViewerEvent {
  const LiveViewerBattleSupportersRefreshRequested();
}

class LiveViewerSocketEventReceived extends LiveViewerEvent {
  final dynamic event;

  const LiveViewerSocketEventReceived(this.event);

  @override
  List<Object?> get props => [identityHashCode(event)];
}

class LiveViewerCommentDeletedRequested extends LiveViewerEvent {
  final String commentId;
  final String? targetUserId;

  const LiveViewerCommentDeletedRequested(this.commentId, {this.targetUserId});

  @override
  List<Object?> get props => [commentId, targetUserId];
}

class LiveViewerViewerChatMuteRequested extends LiveViewerEvent {
  final String userId;
  final String? username;
  final String? reason;

  const LiveViewerViewerChatMuteRequested(
    this.userId, {
    this.username,
    this.reason,
  });

  @override
  List<Object?> get props => [userId, username, reason];
}

class LiveViewerViewerChatUnmuteRequested extends LiveViewerEvent {
  final String userId;
  final String? username;

  const LiveViewerViewerChatUnmuteRequested(this.userId, {this.username});

  @override
  List<Object?> get props => [userId, username];
}

class LiveViewerViewerBannedRequested extends LiveViewerEvent {
  final String userId;
  final String? username;
  final String? reason;

  const LiveViewerViewerBannedRequested(
    this.userId, {
    this.username,
    this.reason,
  });

  @override
  List<Object?> get props => [userId, username, reason];
}

class LiveViewerViewerUnbannedRequested extends LiveViewerEvent {
  final String userId;
  final String? username;

  const LiveViewerViewerUnbannedRequested(this.userId, {this.username});

  @override
  List<Object?> get props => [userId, username];
}

class LiveViewerSendStateChanged extends LiveViewerEvent {
  final bool isSending;

  const LiveViewerSendStateChanged(this.isSending);

  @override
  List<Object?> get props => [isSending];
}

/// Viewer asked the host to come on stage (`POST …/guests/request`).
class LiveViewerGuestSeatRequested extends LiveViewerEvent {
  const LiveViewerGuestSeatRequested();
}

/// Viewer answered an invite addressed to them.
class LiveViewerGuestInviteAnswered extends LiveViewerEvent {
  const LiveViewerGuestInviteAnswered({required this.accepted});

  final bool accepted;

  @override
  List<Object?> get props => [accepted];
}

/// Viewer stepped off the stage and went back to watching.
class LiveViewerLeftStage extends LiveViewerEvent {
  const LiveViewerLeftStage();
}

/// An accepted guest asks the host to start a TikTok-style competition.
///
/// The current server exposes PK creation to live owners only, so this is a
/// stage request delivered through the live conversation for the host to act
/// on; it must not fabricate a local battle state.
class LiveViewerCompetitionRequested extends LiveViewerEvent {
  const LiveViewerCompetitionRequested();
}

/// Re-reads the stage roster (`GET /lives/:id/guests`).
class LiveViewerGuestsRefreshed extends LiveViewerEvent {
  const LiveViewerGuestsRefreshed();
}

/// Internal fallback for a requested seat. The host acceptance event can be
/// lost while Socket.IO is reconnecting, so the authenticated guest checks
/// for publish credentials for a short, bounded window.
class LiveViewerGuestApprovalChecked extends LiveViewerEvent {
  const LiveViewerGuestApprovalChecked({
    required this.liveId,
    this.attempt = 1,
  });

  final String liveId;
  final int attempt;

  @override
  List<Object?> get props => [liveId, attempt];
}

/// Internal bridge from the LiveKit room lifecycle into the session BLoC.
/// Socket.IO and LiveKit reconnect independently, so socket recovery must not
/// be allowed to claim that the video room recovered too.
class LiveViewerLiveKitStateChanged extends LiveViewerEvent {
  const LiveViewerLiveKitStateChanged(this.state);

  final LiveKitConnectionState state;

  @override
  List<Object?> get props => [state];
}

/// Internal bridge from the separate battle LiveKit room into presentation
/// state. The primary room lifecycle must not be used for this room.
class LiveViewerBattleRoomStateChanged extends LiveViewerEvent {
  const LiveViewerBattleRoomStateChanged(this.state);

  final LiveKitConnectionState state;

  @override
  List<Object?> get props => [state];
}
