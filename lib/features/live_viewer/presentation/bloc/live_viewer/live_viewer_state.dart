import 'package:equatable/equatable.dart';
import '../../../domain/entities/comment_entity.dart';
import '../../../domain/entities/gift_entity.dart';
import '../../../domain/entities/live_entity.dart';
import '../../../domain/entities/live_session_entity.dart';

class LiveViewerState extends Equatable {
  final LiveSessionEntity? session;
  final List<CommentEntity> comments;
  final List<GiftSentEntity> recentGifts;
  final GiftSentEntity? activeGiftAnimation;
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

  const LiveViewerState({
    this.session,
    this.comments = const [],
    this.recentGifts = const [],
    this.activeGiftAnimation,
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
  });

  LiveConnectionState get connectionState =>
      session?.connectionState ?? LiveConnectionState.idle;

  LiveEntity? get live => session?.live;

  bool get isPk => live?.metadata?['isPk'] == true;

  LiveViewerState copyWith({
    LiveSessionEntity? session,
    List<CommentEntity>? comments,
    List<GiftSentEntity>? recentGifts,
    GiftSentEntity? activeGiftAnimation,
    bool clearGiftAnimation = false,
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
  }) {
    return LiveViewerState(
      session: session ?? this.session,
      comments: comments ?? this.comments,
      recentGifts: recentGifts ?? this.recentGifts,
      activeGiftAnimation: clearGiftAnimation
          ? null
          : (activeGiftAnimation ?? this.activeGiftAnimation),
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
    );
  }

  @override
  List<Object?> get props => [
    session,
    comments,
    recentGifts,
    activeGiftAnimation,
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
  ];
}
