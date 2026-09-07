import '../entities/live_chat_message.dart';
import '../entities/live_gallery_item.dart';
import '../entities/live_guest.dart';
import '../entities/live_house.dart';
import '../entities/live_interactive.dart';
import '../entities/live_host_league.dart';
import '../entities/live_leaderboard_entry.dart';
import '../entities/live_cohost.dart';
import '../../data/mappers/live_cohost_mapper.dart' show LiveCohostCandidate;
import '../entities/live_moderator.dart';
import '../entities/live_replay.dart';
import '../entities/live_scene.dart';
import '../entities/live_session.dart';
import '../entities/live_share_result.dart';
import '../entities/live_studio.dart';
import '../../../../core/models/live_media_hints.dart';
import '../entities/live_viewer.dart';
import '../../../../core/models/live_battle.dart';

/// Real-time HUD events from Socket.IO (`live_{id}` room).
sealed class LiveHudEvent {
  const LiveHudEvent();
}

class LiveHudCommentEvent extends LiveHudEvent {
  const LiveHudCommentEvent(this.message);
  final LiveChatMessage message;
}

class LiveHudCommentDeletedEvent extends LiveHudEvent {
  const LiveHudCommentDeletedEvent(this.commentId);
  final String commentId;
}

class LiveHudViewersEvent extends LiveHudEvent {
  const LiveHudViewersEvent(this.viewers);
  final int viewers;
}

class LiveHudUserJoinedEvent extends LiveHudEvent {
  const LiveHudUserJoinedEvent({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.viewers,
  });
  final String userId;
  final String username;
  final String? avatarUrl;
  final int? viewers;
}

class LiveHudLikeEvent extends LiveHudEvent {
  const LiveHudLikeEvent({required this.likeCount, this.userId});
  final int likeCount;
  final String? userId;
}

class LiveHudEndedEvent extends LiveHudEvent {
  const LiveHudEndedEvent({required this.liveId, this.status, this.reason});
  final String liveId;
  final String? status;
  final String? reason;
}

/// Socket `livePaused` `{ paused, pausedAt }` — status stays `LIVE`.
class LiveHudPausedEvent extends LiveHudEvent {
  const LiveHudPausedEvent({
    required this.paused,
    this.liveId,
    this.pausedAt,
  });
  final bool paused;
  final String? liveId;
  final DateTime? pausedAt;
}

/// Socket `liveScene` after `PATCH /lives/:id/scene`.
class LiveHudSceneEvent extends LiveHudEvent {
  const LiveHudSceneEvent({
    required this.scene,
    this.liveId,
  });
  final LiveScene scene;
  final String? liveId;
}

/// Socket `liveCameraChanged` `{ liveId, userId, facing, role, at }`.
class LiveHudCameraChangedEvent extends LiveHudEvent {
  const LiveHudCameraChangedEvent({
    required this.userId,
    required this.facing,
    this.liveId,
    this.role,
  });
  final String userId;
  final String facing;
  final String? liveId;
  final String? role;
}

class LiveHudCommentPinnedEvent extends LiveHudEvent {
  const LiveHudCommentPinnedEvent(this.message);
  final LiveChatMessage message;
}

class LiveHudCommentUnpinnedEvent extends LiveHudEvent {
  const LiveHudCommentUnpinnedEvent(this.commentId);
  final String commentId;
}

class LiveHudModerationEvent extends LiveHudEvent {
  const LiveHudModerationEvent({
    required this.type,
    required this.liveId,
    this.userId,
    this.reason,
    this.chatRules,
  });
  final String type;
  final String liveId;
  final String? userId;
  final String? reason;

  /// Present on `chat_rules_updated`.
  final Map<String, dynamic>? chatRules;
}

/// Socket `liveHouse` — room attached or house closed. Payload is thin.
class LiveHudHouseEvent extends LiveHudEvent {
  const LiveHudHouseEvent({
    this.liveId,
    this.houseId,
    this.action,
    this.status,
    this.payload = const {},
  });

  final String? liveId;
  final String? houseId;
  final String? action;
  final String? status;
  final Map<String, dynamic> payload;

  bool get isClosed {
    final value = (status ?? action ?? '').toUpperCase();
    return value == 'CLOSED' || value == 'CLOSE' || value == 'HOUSE_CLOSED';
  }
}

class LiveHudGiftEvent extends LiveHudEvent {
  const LiveHudGiftEvent({
    this.summaryText,
    this.totalEarnedCoins,
    this.senderName,
    this.senderGifterLevel,
    this.senderAvatarUrl,
    this.giftName,
    this.giftIcon,
    this.giftImageUrl,
    this.quantity,
  });
  final String? summaryText;
  final int? totalEarnedCoins;
  final String? senderName;
  final int? senderGifterLevel;

  /// Everything below is what the banner draws. All optional: the payload
  /// varies by gift and older events carry only the summary line.
  final String? senderAvatarUrl;
  final String? giftName;
  final String? giftIcon;
  final String? giftImageUrl;
  final int? quantity;
}

class LiveHudGiftComboEvent extends LiveHudEvent {
  const LiveHudGiftComboEvent({required this.payload, this.totalEarnedCoins});

  final Map<String, dynamic> payload;
  final int? totalEarnedCoins;
}

class LiveHudHourlyRankEvent extends LiveHudEvent {
  const LiveHudHourlyRankEvent({this.hourlyRank, this.label});
  final int? hourlyRank;
  final String? label;
}

/// `liveTopGiftersUpdated` — the supporters strip under each PK tile, and the
/// avatar row in the header of a plain live. Carries the whole ordered list;
/// the stage takes the first three (mobile-api.md §19).
class LiveHudTopGiftersEvent extends LiveHudEvent {
  const LiveHudTopGiftersEvent({
    required this.liveId,
    required this.avatarUrls,
  });
  final String liveId;
  final List<String> avatarUrls;
}

/// Someone invited you onto their stage. Arrives on the personal `user_*`
/// room rather than the live room, so it can land while you are anywhere.
class LiveHudGuestInviteEvent extends LiveHudEvent {
  const LiveHudGuestInviteEvent({this.liveId, this.hostName, this.role});
  final String? liveId;
  final String? hostName;
  final String? role;
}

/// Someone on the stage changed: invited, joined, left, kicked, muted,
/// camera toggled or promoted/demoted — plus `settings` when the host edits
/// the multi-guest policy (mobile-api.md §16, `liveGuestUpdate.type`).
class LiveHudGuestUpdateEvent extends LiveHudEvent {
  const LiveHudGuestUpdateEvent({
    required this.type,
    required this.liveId,
    this.guest,
    this.settings,
  });

  final String type;
  final String liveId;

  /// Raw guest card from the payload; null for `settings` updates.
  final Map<String, dynamic>? guest;
  final Map<String, dynamic>? settings;

  /// Whether the stage roster itself changed, as opposed to policy only.
  bool get affectsStage => type != 'settings';
}

class LiveHudBattleEvent extends LiveHudEvent {
  const LiveHudBattleEvent({required this.type, required this.battle});

  final String type;
  final LiveBattle battle;
}

/// A server push for one of the interactive room features (poll, Q&A, treasure
/// box, auction). The payload is forwarded untouched so the interactive BLoC
/// can apply the server-authoritative update.
class LiveHudInteractiveEvent extends LiveHudEvent {
  const LiveHudInteractiveEvent(this.payload);

  final LiveInteractiveSocketPayload payload;
}

/// The HUD socket came up, or refused to. Comments, the viewer counter and
/// likes all arrive over that socket, so a silent failure looks to the host
/// like three separate features being broken.
class LiveHudConnectionEvent extends LiveHudEvent {
  const LiveHudConnectionEvent({required this.connected, this.reason});
  final bool connected;
  final String? reason;
}

/// LiveKit media health is intentionally separate from [LiveHudConnectionEvent].
/// The video can fail while comments remain connected (and vice versa).
enum LiveMediaConnectionState {
  reconnecting,
  reconnected,
  disconnected,
  failed,
}

class LiveMediaConnectionEvent {
  const LiveMediaConnectionEvent({
    required this.state,
    this.reason,
    this.tag = 'room',
  });

  final LiveMediaConnectionState state;
  final String? reason;
  final String tag;
}

/// LiveKit publish credentials handed to a guest who joined the stage
/// (`POST /lives/:id/guests/accept-invite` / `…/:userId/accept`).
class LiveGuestStageCredentials {
  const LiveGuestStageCredentials({
    required this.token,
    required this.url,
    required this.role,
    this.mediaHints,
  });

  final String token;
  final String url;
  final String role;
  final LiveMediaHints? mediaHints;

  bool get isUsable => token.isNotEmpty && url.isNotEmpty;
}

/// Contract for loading and updating an active live session.
abstract class LiveSessionRepository {
  /// Creates and starts a host live (`POST /lives` with `startNow: true`).
  Future<LiveSession> startHostSession({
    required String title,
    String mediaMode = 'VIDEO',
    String? topic,
  });

  /// Creates a `PLANNED` live (`POST /lives` with `scheduledAt`, no `startNow`).
  /// Does not connect LiveKit. Host starts later via [reconnectHostSession].
  Future<LiveSession> createPlannedSession({
    required String title,
    required DateTime scheduledAt,
    String mediaMode = 'VIDEO',
    String? topic,
  });

  /// Reconnects to an existing LIVE as host (`POST /lives/:id/start`).
  Future<LiveSession> reconnectHostSession(String liveId);

  /// Finds the caller's current `LIVE` session via `GET /lives/mine`, if any.
  Future<LiveSession?> findActiveHostLive();

  /// Ends the active session (`POST /lives/:id/end`) and disconnects HUD/media.
  Future<void> endSession(String sessionId);

  /// Pause without ending (`POST /lives/:id/pause`). Status stays `LIVE`.
  /// Returns the server `paused` flag from `{ paused, pausedAt }`.
  Future<bool> pauseLive(String liveId);

  /// Resume (`POST /lives/:id/resume`). Returns the server `paused` flag.
  Future<bool> resumeLive(String liveId);

  /// Host-only OBS / RTMP bundle (`GET /lives/:id/studio`).
  /// Missing Ingress returns null credentials — never fails go-live.
  Future<LiveStudio?> loadStudio(String liveId);

  /// Persist scene / facing (`PATCH /lives/:id/scene`). Socket `liveScene`.
  Future<LiveScene> updateScene({
    required String liveId,
    required LiveScene scene,
  });

  /// Signaling after a local camera flip (`switchLiveCamera`).
  void emitSwitchLiveCamera({
    required String liveId,
    required String facing,
  });

  /// Loads comments (`GET /lives/:id/comments`).
  Future<List<LiveChatMessage>> loadComments(
    String liveId, {
    int page = 1,
    int limit = 50,
  });

  /// Sends a comment (`POST /lives/:id/comments`).
  Future<LiveChatMessage> sendComment({
    required String liveId,
    required String content,
  });

  /// Deletes a comment (`DELETE /lives/:id/comments/:commentId`).
  Future<void> deleteComment({
    required String liveId,
    required String commentId,
  });

  /// Pins a comment (`POST /lives/:id/comments/:commentId/pin`).
  Future<void> pinComment({required String liveId, required String commentId});

  /// Unpins a comment (`POST /lives/:id/comments/:commentId/unpin`).
  Future<void> unpinComment({
    required String liveId,
    required String commentId,
  });

  /// Mutes a viewer's chat (`POST …/viewers/:userId/mute-chat`).
  Future<void> muteViewerChat({
    required String liveId,
    required String userId,
    String? reason,
  });

  /// Unmutes a viewer's chat.
  Future<void> unmuteViewerChat({
    required String liveId,
    required String userId,
  });

  /// Bans a viewer from this live.
  Future<void> banViewer({
    required String liveId,
    required String userId,
    String? reason,
  });

  /// Unbans a viewer for this live.
  Future<void> unbanViewer({required String liveId, required String userId});

  /// Host-only chat rules (`PATCH /lives/:id/chat-rules`).
  Future<LiveSession> updateChatRules({
    required String liveId,
    String? chatMode,
    int? slowModeSeconds,
    List<String>? blockedKeywords,
  });

  /// Assigned live moderators (`GET /lives/:id/moderators`).
  Future<List<LiveModerator>> loadModerators(String liveId);

  /// Host-only (`POST /lives/:id/moderators` `{ "userId" }`).
  Future<LiveModerator> addModerator({
    required String liveId,
    required String userId,
  });

  /// Host-only (`DELETE /lives/:id/moderators/:userId`).
  Future<void> removeModerator({
    required String liveId,
    required String userId,
  });

  /// `POST /lives/houses` `{ "title" }`.
  Future<LiveHouse> createHouse({required String title});

  /// `GET /lives/houses`.
  Future<List<LiveHouse>> loadHouses();

  /// `GET /lives/houses/:houseId`.
  Future<LiveHouse?> loadHouse(String houseId);

  /// Host attaches their own live (`POST …/houses/:houseId/rooms` `{ liveId }`).
  Future<void> attachLiveToHouse({
    required String houseId,
    required String liveId,
  });

  /// Host closes the house (`PATCH /lives/houses/:houseId`).
  Future<void> closeHouse(String houseId);

  /// Registers a like tap (`POST /lives/:id/like`).
  Future<int> like(String liveId);

  /// Increments `shareCount` (`POST /lives/:id/share`). Use [LiveShareResult.shareUrl].
  Future<LiveShareResult> shareLive(String liveId, {String? channel});

  /// Updates live title (`PATCH /lives/:id`).
  Future<LiveSession> updateTitle({
    required String liveId,
    required String title,
  });

  /// Updates guest policy (`PATCH /lives/:id/settings`).
  Future<LiveSession> updateSettings({
    required String liveId,
    bool? guestsEnabled,
    String? guestRequestMode,
    int? maxGuests,
    String? layout,
    bool? allowGuestCamera,
    bool? moderatorsCanManageGuests,
    String? topic,
    bool? ageRestricted,
    bool? ticketEnabled,
    int? ticketPriceCoins,
  });

  /// Refreshes gallery counts (`GET /lives/:id/gallery`).
  Future<({int current, int total})> loadGalleryCounts(String liveId);

  /// Gallery items (`GET /lives/:id/gallery`).
  Future<List<LiveGalleryItem>> loadGalleryItems(String liveId);

  /// Pin/unpin auction in gallery (`PATCH …/auctions/:id/pin`).
  /// Host reorder (`PATCH /lives/:id/auctions/reorder` with `auctionIds`).
  Future<void> reorderGalleryItems({
    required String liveId,
    required List<String> auctionIds,
  });

  Future<void> pinGalleryItem({
    required String liveId,
    required String auctionId,
    required bool pinned,
  });

  /// Counts REQUESTED + INVITED guests (`GET /lives/:id/guests`).
  Future<int> loadGuestPendingCount(String liveId);

  /// Full guest list (`GET /lives/:id/guests`).
  Future<List<LiveGuest>> loadGuests(String liveId);

  /// Who is watching right now (`GET /lives/:id/viewers`).
  Future<List<LiveViewer>> loadViewers(String liveId);

  Future<void> inviteGuest({
    required String liveId,
    required String userId,
    String role = 'GUEST',
  });

  /// Invitee accepts their own invite (`POST /lives/:id/guests/accept-invite`).
  /// Returns the LiveKit publish credentials that put them on stage.
  Future<LiveGuestStageCredentials> acceptGuestInvite(String liveId);

  /// Active guest steps off the stage (`POST /lives/:id/guests/leave`).
  Future<void> leaveGuestStage(String liveId);

  Future<void> acceptGuest({required String liveId, required String userId});

  Future<void> rejectGuest({required String liveId, required String userId});

  Future<void> kickGuest({required String liveId, required String userId});

  Future<void> muteGuest({required String liveId, required String userId});

  Future<void> unmuteGuest({required String liveId, required String userId});

  Future<void> setGuestCameraOff({
    required String liveId,
    required String userId,
  });

  Future<void> setGuestCameraOn({
    required String liveId,
    required String userId,
  });

  Future<void> promoteGuest({required String liveId, required String userId});

  Future<void> demoteGuest({required String liveId, required String userId});

  Future<LiveBattle?> loadBattle(String liveId);

  Future<List<LiveBattleOpponent>> loadBattleOpponents(
    String liveId, {
    int limit = 20,
  });

  /// `POST /lives/:id/battle`. Solo (1v1) stays the default; [teamMode] opens
  /// a 2v2 lobby with the two captains and optional teammate seats
  /// (`lives/live-p1-parity.md` §7). [bestOf] is 1 or 3 (`live-p2-parity.md`).
  Future<LiveBattle> startBattle({
    required String liveId,
    required String opponentLiveId,
    int durationSeconds = 300,
    bool teamMode = false,
    String? scoringMode,
    String? scoringGiftId,
    int? bestOf,
    String? teammateLiveId,
    String? opponentTeammateLiveId,
  });

  Future<LiveBattle> matchBattle(
    String liveId, {
    int durationSeconds = 300,
    bool teamMode = false,
  });

  /// `GET /lives/:id/battle/open-teams` — lobbies with a free teammate slot.
  Future<List<LiveBattle>> loadOpenTeamBattles(String liveId);

  /// `POST /lives/:yourLiveId/battle/:battleId/join`. Omit [team] to take the
  /// first open slot.
  Future<LiveBattle> joinBattleTeam({
    required String liveId,
    required String battleId,
    int? team,
  });

  /// `POST /lives/:captainLiveId/battle/:battleId/invite`.
  Future<LiveBattle> inviteBattleTeammate({
    required String liveId,
    required String battleId,
    required String teammateLiveId,
  });

  /// `POST /lives/:teammateLiveId/battle/:battleId/leave` — teammates only.
  Future<LiveBattle?> leaveBattleTeam({
    required String liveId,
    required String battleId,
  });

  /// `POST /lives/:id/battle/:battleId/power-up` — STUN, TIME or GLOVE.
  Future<LiveBattle> activateBattlePowerUp({
    required String liveId,
    required String battleId,
    required String type,
  });

  // ── Multi-room co-host ─────────────────────────────────────

  /// `GET /lives/:id/cohost/hosts` — hosts with a free slot.
  Future<List<LiveCohostCandidate>> loadCohostCandidates(String liveId);

  /// `GET /lives/:id/cohost` — this room's sessions.
  Future<List<LiveCohostSession>> loadCohostSessions(String liveId);

  /// `POST /lives/:id/cohost/invite`.
  Future<LiveCohostSession?> inviteCohost({
    required String liveId,
    required String guestLiveId,
  });

  /// `POST /lives/:id/cohost/:sessionId/accept`.
  Future<LiveCohostSession?> acceptCohost({
    required String liveId,
    required String sessionId,
  });

  /// `POST /lives/:id/cohost/:sessionId/end`.
  Future<void> endCohost({required String liveId, required String sessionId});

  /// Tiles every partner room from `cohosts[]` as its own subscribe-only
  /// LiveKit connection, and drops the ones no longer listed.
  Future<void> syncCohostMedia(LiveCohostPayload payload);

  /// Closes every partner room. The primary room is untouched.
  Future<void> disconnectCohostMedia();

  Future<LiveBattle> activateBattleMultiplier({
    required String liveId,
    required double multiplier,
    required int durationSeconds,
  });

  Future<LiveBattle> endBattle({
    required String liveId,
    required String battleId,
  });

  /// Subscribe to the opponent host's separate LiveKit room.
  Future<void> connectBattleOpponentMedia(String opponentLiveId);

  Future<void> disconnectBattleOpponentMedia();

  /// Hourly rank for this live (`GET /lives/:id/leaderboard/hourly`).
  Future<({int? rank, String label, int? score, int? coins})> loadHourlyRank(
    String liveId,
  );

  /// Global hourly host leaderboard (`GET /lives/leaderboard/hourly`).
  Future<List<LiveLeaderboardEntry>> loadGlobalHourlyLeaderboard({
    int limit = 20,
  });

  /// `GET /lives/:id/replay` — plays the replay and counts one replay view
  /// on the server. Never called for a live that is still running.
  Future<LiveReplay> loadReplay(String liveId);

  /// `POST /lives/:id/replay` — host publishes a URL when Egress failed.
  Future<LiveReplay> publishReplay({
    required String liveId,
    required String replayUrl,
  });

  /// `DELETE /lives/:id/replay` — host takedown.
  Future<void> removeReplay(String liveId);

  /// `GET /lives/:id/clips`.
  Future<List<LiveClip>> loadClips(String liveId);

  /// `POST /lives/:id/clips` — requires a READY replay.
  Future<LiveClip> createClip({
    required String liveId,
    required num startSeconds,
    required num endSeconds,
    String? title,
    String? clipUrl,
  });

  /// `POST /lives/:id/clips/:clipId/post` — idempotent on the server.
  Future<LiveClip> postClip({
    required String liveId,
    required String clipId,
    String? description,
  });

  /// League tier table (`GET /lives/leagues`).
  Future<List<LiveLeagueTier>> loadLeagueTiers();

  /// One creator's league tier and progress (`GET /lives/host-league/:userId`).
  Future<LiveHostLeague?> loadHostLeague(String userId);

  /// Top gifters for this live (`GET /lives/:id/leaderboard/gifters`).
  Future<List<LiveLeaderboardEntry>> loadGiftersLeaderboard(
    String liveId, {
    String window = 'hour',
  });

  /// Connects Socket.IO and joins `live_{id}`.
  Future<void> connectRealtime(String liveId);

  /// Leaves the socket room and disconnects.
  Future<void> disconnectRealtime();

  /// HUD event stream while connected.
  Stream<LiveHudEvent> get hudEvents;

  /// Host LiveKit room lifecycle. A terminal disconnect requires a fresh host
  /// token from `POST /lives/:id/start`, not only a Socket.IO reconnect.
  Stream<LiveMediaConnectionEvent> get mediaEvents;

  /// Publishes host A/V to LiveKit using token/url from start.
  ///
  /// [beforeVideoCapture] runs after the room and microphone are connected but
  /// immediately before WebRTC opens the camera. The host uses it to release
  /// the setup preview, guaranteeing that two camera engines never contend for
  /// the same lens. [maxAttempts] bounds the resolution fallback ladder.
  Future<void> connectMedia({
    required String url,
    required String token,
    bool useFrontCamera = true,
    int maxAttempts = 3,
    Future<void> Function()? beforeVideoCapture,
    LiveMediaHints? mediaHints,
    bool useArBeautyCamera = false,
  });

  /// Publish or stop LiveKit screen share (`SCREEN` / `DUAL` scenes).
  Future<void> setScreenShareEnabled(bool enabled);

  Object? get localScreenShareTrack;

  /// Viewer subscribe-only LiveKit connect.
  Future<void> connectMediaSubscribe({
    required String url,
    required String token,
    LiveMediaHints? mediaHints,
  });

  Future<void> disconnectMedia();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  /// Flip LiveKit camera (front/back).
  Future<void> flipMediaCamera({required bool useFront});

  /// Pause / resume outbound stall watchdog around camera flip.
  void pauseOutboundMediaHealthCheck();

  void resumeOutboundMediaHealthCheck();

  /// Mute outbound camera to the SFU while the lens rebinds (viewer keeps
  /// last good frame instead of decoding corrupt YUV).
  Future<void> muteOutboundVideoForCameraFlip();

  Future<void> unmuteOutboundVideoAfterCameraFlip();

  /// Opaque local LiveKit video track for UI preview (`LocalVideoTrack`).
  Object? get localPreviewTrack;

  /// Opaque LiveKit `Room`, or null before media connects. The stage reads
  /// remote participants from it to render guests who are publishing.
  Object? get mediaRoom;

  Object? get battleMediaRoom;

  /// True while the PK opponent LiveKit room is connected and usable.
  bool get isBattleRoomUsable;

  /// Whether LiveKit host/guest publish is active (mic and/or video).
  bool get isMediaConnected;
}
