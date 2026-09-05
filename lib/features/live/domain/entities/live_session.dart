import 'live_chat_message.dart';
import 'live_host.dart';
import 'live_chat_rules.dart';
import '../../../../core/models/live_media_hints.dart';

/// Snapshot of an active live broadcasting session (fields from mobile-api.md §5).
class LiveSession {
  const LiveSession({
    required this.id,
    required this.host,
    required this.viewerCount,
    required this.likeCount,
    required this.galleryCurrent,
    required this.galleryTotal,
    required this.guestInviteCount,
    required this.hourlyRankingLabel,
    required this.messages,
    this.title,
    this.status = 'LIVE',
    this.roomName,
    this.streamUrl,
    this.coverUrl,
    this.categoryId,
    this.guestsEnabled,
    this.guestRequestMode,
    this.maxGuests,
    this.layout,
    this.allowGuestCamera,
    this.moderatorsCanManageGuests,
    this.chatRules,
    this.liveKitToken,
    this.liveKitUrl,
    this.liveKitRole,
    this.mediaHints,
    this.hourlyRank,
    this.totalEarnedCoins = 0,
    this.isPopular,
    this.popularReason,
  });

  final String id;
  final LiveHost host;
  final int viewerCount;
  final int likeCount;
  final int galleryCurrent;
  final int galleryTotal;
  final int guestInviteCount;
  final String hourlyRankingLabel;
  final List<LiveChatMessage> messages;

  /// Live title from backend (`title`).
  final String? title;

  /// Backend status: `PLANNED` | `LIVE` | `ENDED` | `BANNED`.
  final String status;

  final String? roomName;
  final String? streamUrl;
  final String? coverUrl;
  final String? categoryId;
  final bool? guestsEnabled;
  final String? guestRequestMode;
  final int? maxGuests;

  /// UI hint: `GRID` | `PANEL`.
  final String? layout;
  final bool? allowGuestCamera;
  final bool? moderatorsCanManageGuests;
  final LiveChatRules? chatRules;

  /// LiveKit JWT from start/join (never mint on device).
  final String? liveKitToken;

  /// LiveKit server URL from start/join.
  final String? liveKitUrl;

  /// LiveKit role (`host`, `viewer`, `guest`, `co_host`).
  final String? liveKitRole;

  /// Latest server recommendations for this exact token/role.
  final LiveMediaHints? mediaHints;

  final int? hourlyRank;
  final int totalEarnedCoins;
  final bool? isPopular;
  final String? popularReason;

  bool get isLive => status == 'LIVE';

  LiveSession copyWith({
    String? id,
    LiveHost? host,
    int? viewerCount,
    int? likeCount,
    int? galleryCurrent,
    int? galleryTotal,
    int? guestInviteCount,
    String? hourlyRankingLabel,
    List<LiveChatMessage>? messages,
    String? title,
    String? status,
    String? roomName,
    String? streamUrl,
    String? coverUrl,
    String? categoryId,
    bool? guestsEnabled,
    String? guestRequestMode,
    int? maxGuests,
    String? layout,
    bool? allowGuestCamera,
    bool? moderatorsCanManageGuests,
    LiveChatRules? chatRules,
    String? liveKitToken,
    String? liveKitUrl,
    String? liveKitRole,
    LiveMediaHints? mediaHints,
    int? hourlyRank,
    int? totalEarnedCoins,
    bool? isPopular,
    String? popularReason,
  }) {
    return LiveSession(
      id: id ?? this.id,
      host: host ?? this.host,
      viewerCount: viewerCount ?? this.viewerCount,
      likeCount: likeCount ?? this.likeCount,
      galleryCurrent: galleryCurrent ?? this.galleryCurrent,
      galleryTotal: galleryTotal ?? this.galleryTotal,
      guestInviteCount: guestInviteCount ?? this.guestInviteCount,
      hourlyRankingLabel: hourlyRankingLabel ?? this.hourlyRankingLabel,
      messages: messages ?? this.messages,
      title: title ?? this.title,
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      streamUrl: streamUrl ?? this.streamUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      categoryId: categoryId ?? this.categoryId,
      guestsEnabled: guestsEnabled ?? this.guestsEnabled,
      guestRequestMode: guestRequestMode ?? this.guestRequestMode,
      maxGuests: maxGuests ?? this.maxGuests,
      layout: layout ?? this.layout,
      allowGuestCamera: allowGuestCamera ?? this.allowGuestCamera,
      moderatorsCanManageGuests:
          moderatorsCanManageGuests ?? this.moderatorsCanManageGuests,
      chatRules: chatRules ?? this.chatRules,
      liveKitToken: liveKitToken ?? this.liveKitToken,
      liveKitUrl: liveKitUrl ?? this.liveKitUrl,
      liveKitRole: liveKitRole ?? this.liveKitRole,
      mediaHints: mediaHints ?? this.mediaHints,
      hourlyRank: hourlyRank ?? this.hourlyRank,
      totalEarnedCoins: totalEarnedCoins ?? this.totalEarnedCoins,
      isPopular: isPopular ?? this.isPopular,
      popularReason: popularReason ?? this.popularReason,
    );
  }
}
