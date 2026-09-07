import 'live_chat_message.dart';
import 'live_host.dart';
import 'live_cohost.dart';
import 'live_interactive.dart';
import 'live_scene.dart';
import 'live_studio.dart';
import '../../../../core/models/live_media_hints.dart';
import '../../../../core/models/live_media_mode.dart';

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
    this.ticketEnabled,
    this.ticketPriceCoins,
    this.liveKitToken,
    this.liveKitUrl,
    this.liveKitRole,
    this.mediaHints,
    this.hourlyRank,
    this.totalEarnedCoins = 0,
    this.giftGoal,
    this.isPopular,
    this.popularReason,
    this.paused = false,
    this.mediaMode = LiveMediaMode.video,
    this.audioOnly = false,
    this.cohost = LiveCohostPayload.none,
    this.scene = const LiveScene(),
    this.studio,
    this.topic,
    this.scheduledAt,
    this.shareCount = 0,
    this.chatMode = 'EVERYONE',
    this.slowModeSeconds = 0,
    this.blockedKeywords = const [],
    this.moderatorIds = const [],
    this.houseId,
    this.ageRestricted = false,
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

  /// Paid-entry policy returned by the LIVE API. Null means this response did
  /// not include the P3 ticket fields; it must not be treated as free entry.
  final bool? ticketEnabled;
  final int? ticketPriceCoins;

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

  /// Gift goal carried by `GET /lives/:id`. Null when the stream has none.
  final LiveGiftGoal? giftGoal;
  final bool? isPopular;
  final String? popularReason;

  /// Server pause flag (`paused`). Status stays `LIVE` while this is true.
  final bool paused;

  /// Stored `VIDEO` | `AUDIO`. Cannot change after the live has started.
  final String mediaMode;

  /// True for Voice Chat rooms. Host/speakers publish microphone only.
  final bool audioOnly;

  /// Partner rooms to tile beside this one, from `cohost` / `cohosts[]` on the
  /// join/start payload (`lives/live-p2-parity.md` §2). Empty for a solo room.
  final LiveCohostPayload cohost;

  /// Backend-backed scene (CAMERA / SCREEN / DUAL + facing).
  final LiveScene scene;

  /// Host-only OBS / RTMP bundle. Never expose [LiveStudio.streamKey] to viewers.
  final LiveStudio? studio;

  /// Radio / room topic (max 80). Shown on the card; Feature #3 filters feed.
  final String? topic;

  /// Future start time for `PLANNED` lives. Immediate `startNow` lives omit this.
  final DateTime? scheduledAt;

  final int shareCount;

  /// `EVERYONE` | `FOLLOWERS` | `SUBSCRIBERS` (`PATCH /lives/:id/chat-rules`).
  final String chatMode;

  /// Seconds between viewer comments. 0 disables slow mode. Max 60.
  final int slowModeSeconds;

  final List<String> blockedKeywords;

  /// User ids from `GET /lives/:id/moderators`.
  final List<String> moderatorIds;

  /// LIVE House venue id when this live is attached as a room.
  final String? houseId;

  /// 18+ join/detail gate (`PATCH /lives/:id/settings`).
  final bool ageRestricted;

  bool get isLive => status == 'LIVE';

  bool get isPlanned => status.toUpperCase() == 'PLANNED';

  bool get isAudioOnly =>
      LiveMediaMode.isAudio(mediaMode: mediaMode, audioOnly: audioOnly) ||
      (mediaHints?.audioOnly ?? false);

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
    bool? ticketEnabled,
    int? ticketPriceCoins,
    String? liveKitToken,
    String? liveKitUrl,
    String? liveKitRole,
    LiveMediaHints? mediaHints,
    int? hourlyRank,
    int? totalEarnedCoins,
    bool? isPopular,
    String? popularReason,
    bool? paused,
    String? mediaMode,
    bool? audioOnly,
    LiveCohostPayload? cohost,
    LiveScene? scene,
    LiveStudio? studio,
    String? topic,
    DateTime? scheduledAt,
    int? shareCount,
    String? chatMode,
    int? slowModeSeconds,
    List<String>? blockedKeywords,
    List<String>? moderatorIds,
    Object? houseId = _liveSessionUnset,
    bool? ageRestricted,
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
      ticketEnabled: ticketEnabled ?? this.ticketEnabled,
      ticketPriceCoins: ticketPriceCoins ?? this.ticketPriceCoins,
      liveKitToken: liveKitToken ?? this.liveKitToken,
      liveKitUrl: liveKitUrl ?? this.liveKitUrl,
      liveKitRole: liveKitRole ?? this.liveKitRole,
      mediaHints: mediaHints ?? this.mediaHints,
      hourlyRank: hourlyRank ?? this.hourlyRank,
      totalEarnedCoins: totalEarnedCoins ?? this.totalEarnedCoins,
      isPopular: isPopular ?? this.isPopular,
      popularReason: popularReason ?? this.popularReason,
      paused: paused ?? this.paused,
      mediaMode: mediaMode ?? this.mediaMode,
      audioOnly: audioOnly ?? this.audioOnly,
      cohost: cohost ?? this.cohost,
      scene: scene ?? this.scene,
      studio: studio ?? this.studio,
      topic: topic ?? this.topic,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      shareCount: shareCount ?? this.shareCount,
      chatMode: chatMode ?? this.chatMode,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      blockedKeywords: blockedKeywords ?? this.blockedKeywords,
      moderatorIds: moderatorIds ?? this.moderatorIds,
      houseId: identical(houseId, _liveSessionUnset)
          ? this.houseId
          : houseId as String?,
      ageRestricted: ageRestricted ?? this.ageRestricted,
    );
  }
}

const Object _liveSessionUnset = Object();
