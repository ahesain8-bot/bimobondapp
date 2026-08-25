import 'package:equatable/equatable.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import '../../../domain/entities/comment_entity.dart';
import '../../../domain/entities/gift_entity.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/entities/live_session_entity.dart';
import '../../../domain/repositories/guest_repository.dart';
import '../../../../../core/models/live_battle.dart';

class LiveViewerState extends Equatable {
  final LiveSessionEntity? session;
  final List<CommentEntity> comments;
  final List<GiftSentEntity> recentGifts;
  final GiftSentEntity? activeGiftAnimation;
  final GiftComboPayload? latestGiftCombo;
  final int floatingHeartBurst;
  final int coinDelta;
  final bool showJoinSuccess;
  final List<String> topViewerAvatars;
  final int pkScoreLeft;
  final int pkScoreRight;
  final CommentEntity? pinnedComment;
  final bool chatMuted;
  final String? moderationBanner;
  final String? currentUserId;
  final Set<String> bannedUserIds;
  final Set<String> mutedUserIds;
  final bool isCommentSending;

  /// Everyone on or waiting for the stage (`GET /lives/:id/guests`).
  final List<GuestSummary> guests;

  /// An invite for this viewer that has not been answered yet.
  final PendingGuestInvite? pendingGuestInvite;

  /// True once this device is publishing camera/mic into the room.
  final bool isOnStage;

  /// True while a request/accept/leave call is in flight.
  final bool isGuestActionBusy;

  /// Current battle snapshot from REST/Socket.IO.
  final LiveBattle? battle;

  const LiveViewerState({
    this.session,
    this.comments = const [],
    this.recentGifts = const [],
    this.activeGiftAnimation,
    this.latestGiftCombo,
    this.floatingHeartBurst = 0,
    this.coinDelta = 0,
    this.showJoinSuccess = false,
    this.topViewerAvatars = const [],
    this.pkScoreLeft = 0,
    this.pkScoreRight = 0,
    this.pinnedComment,
    this.chatMuted = false,
    this.moderationBanner,
    this.currentUserId,
    this.bannedUserIds = const {},
    this.mutedUserIds = const {},
    this.isCommentSending = false,
    this.guests = const [],
    this.pendingGuestInvite,
    this.isOnStage = false,
    this.isGuestActionBusy = false,
    this.battle,
  });

  /// Guests actually publishing right now — what the stage renders.
  List<GuestSummary> get activeGuests =>
      guests.where((g) => g.isActive).toList(growable: false);

  LiveConnectionState get connectionState =>
      session?.connectionState ?? LiveConnectionState.idle;

  LiveEntity? get live => session?.live;

  /// PK is server-authoritative. A stale `isPk`/`battle` field in live
  /// metadata must never turn an accepted guest into the battle UI.
  bool get isPk => battle?.isActive == true;

  LiveViewerState copyWith({
    LiveSessionEntity? session,
    List<CommentEntity>? comments,
    List<GiftSentEntity>? recentGifts,
    GiftSentEntity? activeGiftAnimation,
    GiftComboPayload? latestGiftCombo,
    bool clearGiftAnimation = false,
    bool clearGiftCombo = false,
    int? floatingHeartBurst,
    int? coinDelta,
    bool? showJoinSuccess,
    List<String>? topViewerAvatars,
    int? pkScoreLeft,
    int? pkScoreRight,
    CommentEntity? pinnedComment,
    bool clearPinnedComment = false,
    bool? chatMuted,
    String? moderationBanner,
    bool clearModerationBanner = false,
    String? currentUserId,
    Set<String>? bannedUserIds,
    Set<String>? mutedUserIds,
    bool? isCommentSending,
    List<GuestSummary>? guests,
    PendingGuestInvite? pendingGuestInvite,
    bool clearPendingGuestInvite = false,
    bool? isOnStage,
    bool? isGuestActionBusy,
    LiveBattle? battle,
    bool clearBattle = false,
  }) {
    return LiveViewerState(
      session: session ?? this.session,
      comments: comments ?? this.comments,
      recentGifts: recentGifts ?? this.recentGifts,
      activeGiftAnimation: clearGiftAnimation
          ? null
          : (activeGiftAnimation ?? this.activeGiftAnimation),
      latestGiftCombo: clearGiftCombo
          ? null
          : (latestGiftCombo ?? this.latestGiftCombo),
      floatingHeartBurst: floatingHeartBurst ?? this.floatingHeartBurst,
      coinDelta: coinDelta ?? this.coinDelta,
      showJoinSuccess: showJoinSuccess ?? this.showJoinSuccess,
      topViewerAvatars: topViewerAvatars ?? this.topViewerAvatars,
      pkScoreLeft: pkScoreLeft ?? this.pkScoreLeft,
      pkScoreRight: pkScoreRight ?? this.pkScoreRight,
      pinnedComment: clearPinnedComment
          ? null
          : (pinnedComment ?? this.pinnedComment),
      chatMuted: chatMuted ?? this.chatMuted,
      moderationBanner: clearModerationBanner
          ? null
          : (moderationBanner ?? this.moderationBanner),
      currentUserId: currentUserId ?? this.currentUserId,
      bannedUserIds: bannedUserIds ?? this.bannedUserIds,
      mutedUserIds: mutedUserIds ?? this.mutedUserIds,
      isCommentSending: isCommentSending ?? this.isCommentSending,
      guests: guests ?? this.guests,
      pendingGuestInvite: clearPendingGuestInvite
          ? null
          : (pendingGuestInvite ?? this.pendingGuestInvite),
      isOnStage: isOnStage ?? this.isOnStage,
      isGuestActionBusy: isGuestActionBusy ?? this.isGuestActionBusy,
      battle: clearBattle ? null : (battle ?? this.battle),
    );
  }

  @override
  List<Object?> get props => [
    session,
    comments,
    recentGifts,
    activeGiftAnimation,
    latestGiftCombo,
    floatingHeartBurst,
    coinDelta,
    showJoinSuccess,
    topViewerAvatars,
    pkScoreLeft,
    pkScoreRight,
    pinnedComment,
    chatMuted,
    moderationBanner,
    currentUserId,
    bannedUserIds,
    mutedUserIds,
    isCommentSending,
    guests,
    pendingGuestInvite,
    isOnStage,
    isGuestActionBusy,
    battle,
  ];
}

/// An unanswered `liveGuestInvite`, kept in state so the prompt stays on
/// screen until the viewer actually answers it.
class PendingGuestInvite extends Equatable {
  const PendingGuestInvite({
    required this.liveId,
    required this.hostName,
    required this.role,
  });

  final String liveId;
  final String hostName;
  final String role;

  bool get isCoHost => role.toUpperCase() == 'CO_HOST';

  @override
  List<Object?> get props => [liveId, hostName, role];
}
