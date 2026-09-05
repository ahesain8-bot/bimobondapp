import '../entities/live_chat_message.dart';
import '../entities/live_gallery_item.dart';
import '../entities/live_guest.dart';
import '../entities/live_interactive.dart';
import '../entities/live_leaderboard_entry.dart';
import '../entities/live_session.dart';
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
  });
  final String type;
  final String liveId;
  final String? userId;
  final String? reason;
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
  Future<LiveSession> startHostSession({required String title});

  /// Reconnects to an existing LIVE as host (`POST /lives/:id/start`).
  Future<LiveSession> reconnectHostSession(String liveId);

  /// Finds the caller's current `LIVE` session via `GET /lives/mine`, if any.
  Future<LiveSession?> findActiveHostLive();

  /// Ends the active session (`POST /lives/:id/end`) and disconnects HUD/media.
  Future<void> endSession(String sessionId);

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

  /// Registers a like tap (`POST /lives/:id/like`).
  Future<int> like(String liveId);

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
  });

  /// Refreshes gallery counts (`GET /lives/:id/gallery`).
  Future<({int current, int total})> loadGalleryCounts(String liveId);

  /// Gallery items (`GET /lives/:id/gallery`).
  Future<List<LiveGalleryItem>> loadGalleryItems(String liveId);

  /// Pin/unpin auction in gallery (`PATCH …/auctions/:id/pin`).
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

  Future<LiveBattle> startBattle({
    required String liveId,
    required String opponentLiveId,
    int durationSeconds = 300,
  });

  Future<LiveBattle> matchBattle(String liveId, {int durationSeconds = 300});

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

  /// Viewer subscribe-only LiveKit connect.
  Future<void> connectMediaSubscribe({
    required String url,
    required String token,
    LiveMediaHints? mediaHints,
  });

  Future<void> disconnectMedia();

  Future<void> setMicrophoneEnabled(bool enabled);

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

  /// Whether LiveKit host/guest publish is active (video published).
  bool get isMediaConnected;
}
