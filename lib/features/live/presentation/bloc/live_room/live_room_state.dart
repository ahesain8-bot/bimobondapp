import 'package:camera/camera.dart';
import 'package:bimobondapp/app/camera_engine/native_camera_controller.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:bimobondapp/app/auctions/data/datasources/auction_socket_service.dart';
import '../../../../../core/models/live_battle.dart';
import '../../../../../core/models/live_competition_request.dart';

import '../../../domain/effects/live_effects_catalog.dart';
import '../../../domain/entities/live_guest.dart';
import '../../../domain/entities/live_session.dart';
import 'live_room_event.dart';
import '../../../domain/entities/live_gift_banner.dart';

const Object _unset = Object();

/// States emitted by [LiveRoomBloc].
sealed class LiveRoomState {
  const LiveRoomState();
}

class LiveRoomInitial extends LiveRoomState {
  const LiveRoomInitial();
}

class LiveRoomLoading extends LiveRoomState {
  const LiveRoomLoading();
}

/// Local camera is open; Nest session / LiveKit may still be connecting.
class LiveRoomOpening extends LiveRoomState {
  const LiveRoomOpening({
    this.controller,
    this.nativeController,
    this.isCameraInitialized = false,
    this.isFrontCamera = true,
  });

  final CameraController? controller;
  final NativeCameraController? nativeController;
  final bool isCameraInitialized;
  final bool isFrontCamera;
}

class LiveRoomFailure extends LiveRoomState {
  const LiveRoomFailure({
    required this.message,
    this.isActiveLiveConflict = false,
    this.pendingTitle,
    this.isRecovering = false,
  });

  final String message;

  /// Nest `400` when the host already has another `LIVE` stream.
  final bool isActiveLiveConflict;

  /// Title to reuse after ending the stuck live and restarting.
  final String? pendingTitle;

  /// True while end/resume recovery is in flight.
  final bool isRecovering;
}

/// Live room is active and ready to render overlays.
class LiveRoomReady extends LiveRoomState {
  const LiveRoomReady({
    required this.session,
    this.controller,
    this.nativeController,
    this.localVideoTrack,
    this.isCameraInitialized = false,
    this.isFrontCamera = true,
    this.selectedEffectId = 'none',
    this.effectsPanelMode = LiveEffectsPanelMode.hidden,
    this.effectsCategoryId = LiveEffectsCatalog.categoryTrending,
    this.isMirrorEnabled = false,
    this.isMicMuted = false,
    this.isStabilizationEnabled = true,
    this.isNoiseReductionEnabled = false,
    this.isAiContentTagged = false,
    this.isLivePaused = false,
    this.showLiveGiftsBadge = true,
    this.showLiveTitleBadge = true,
    this.isMediaConnected = false,
    this.isChatComposerVisible = false,
    this.isSendingChat = false,
    this.isEnding = false,
    this.actionMessage,
    this.floatingHeartBurst = 0,
    this.giftBanner,
    this.latestGiftCombo,
    this.isRealtimeConnected = false,
    this.guests = const [],
    this.pendingGuestInvite,
    this.pendingCompetitionRequest,
    this.isCompetitionActionBusy = false,
    this.battle,
    this.battleMediaRoom,
    this.topGifterAvatars = const [],
    this.opponentTopGifterAvatars = const [],
  });

  final LiveSession session;

  /// Optional Flutter [CameraController] (effects / fallback preview only).
  final CameraController? controller;

  /// CameraX/GPU preview used until LiveKit opens its native WebRTC capturer.
  final NativeCameraController? nativeController;

  /// LiveKit local camera track for [VideoTrackRenderer] host preview.
  final VideoTrack? localVideoTrack;

  final bool isCameraInitialized;
  final bool isFrontCamera;
  final String selectedEffectId;
  final LiveEffectsPanelMode effectsPanelMode;
  final String effectsCategoryId;
  final bool isMirrorEnabled;
  final bool isMicMuted;
  final bool isStabilizationEnabled;
  final bool isNoiseReductionEnabled;
  final bool isAiContentTagged;
  final bool isLivePaused;
  final bool showLiveGiftsBadge;
  final bool showLiveTitleBadge;

  /// True when LiveKit publish is active.
  final bool isMediaConnected;

  final bool isChatComposerVisible;
  final bool isSendingChat;
  final bool isEnding;

  /// Transient user-facing message (missing API / errors).
  final String? actionMessage;

  /// Increment to spawn floating hearts (TikTok-style like burst).
  final int floatingHeartBurst;

  /// Most recent gift to celebrate, cleared once the banner has played.
  final LiveGiftBanner? giftBanner;

  /// Canonical `gift_combo` payload for the shared gift presentation layer.
  final GiftComboPayload? latestGiftCombo;

  /// Whether the HUD socket is up. Comments, the viewer counter and likes all
  /// ride it, so the room shows this instead of letting three features look
  /// independently broken.
  final bool isRealtimeConnected;

  /// Everyone on or waiting for the stage (`GET /lives/:id/guests`).
  final List<LiveGuest> guests;

  /// An invite addressed to this user that has not been answered yet.
  final LivePendingGuestInvite? pendingGuestInvite;

  /// An active guest asked the host to start a PK round. This is rendered as
  /// an actionable card, never as an ordinary chat line.
  final LiveCompetitionRequest? pendingCompetitionRequest;

  /// Prevents accepting/rejecting the same request more than once while the
  /// server starts the battle.
  final bool isCompetitionActionBusy;

  /// Current server-authoritative PK battle, if this live is paired.
  final LiveBattle? battle;

  /// The subscribe-only LiveKit room for the opponent's battle stream.
  ///
  /// This is deliberately part of BLoC state. The media repository owns the
  /// imperative Room, but the stage must be told when that Room becomes
  /// available instead of relying on an unchanged [battle] value to trigger a
  /// rebuild.
  final Room? battleMediaRoom;

  /// Ordered supporter avatars for this live — the top-gifter ring TikTok
  /// draws under the host's own PK tile. From
  /// `GET /lives/:id/leaderboard/gifters` and `liveTopGiftersUpdated`.
  final List<String> topGifterAvatars;

  /// The same, for the opponent's side of an active battle.
  final List<String> opponentTopGifterAvatars;

  bool get isBattleActive => battle?.isActive == true;

  /// Guests actually publishing right now — what the stage renders.
  List<LiveGuest> get activeGuests =>
      guests.where((g) => g.isActive).toList(growable: false);

  /// Viewers waiting on the host to let them on stage.
  List<LiveGuest> get requestingGuests =>
      guests.where((g) => g.isRequesting).toList(growable: false);

  LiveRoomReady copyWith({
    LiveSession? session,
    Object? controller = _unset,
    Object? nativeController = _unset,
    Object? localVideoTrack = _unset,
    bool? isCameraInitialized,
    bool? isFrontCamera,
    String? selectedEffectId,
    LiveEffectsPanelMode? effectsPanelMode,
    String? effectsCategoryId,
    bool? isMirrorEnabled,
    bool? isMicMuted,
    bool? isStabilizationEnabled,
    bool? isNoiseReductionEnabled,
    bool? isAiContentTagged,
    bool? isLivePaused,
    bool? showLiveGiftsBadge,
    bool? showLiveTitleBadge,
    bool? isMediaConnected,
    bool? isChatComposerVisible,
    bool? isSendingChat,
    bool? isEnding,
    String? actionMessage,
    bool clearActionMessage = false,
    int? floatingHeartBurst,
    Object? giftBanner = _unset,
    Object? latestGiftCombo = _unset,
    bool? isRealtimeConnected,
    List<LiveGuest>? guests,
    Object? pendingGuestInvite = _unset,
    Object? pendingCompetitionRequest = _unset,
    bool? isCompetitionActionBusy,
    Object? battle = _unset,
    Object? battleMediaRoom = _unset,
    List<String>? topGifterAvatars,
    List<String>? opponentTopGifterAvatars,
  }) {
    return LiveRoomReady(
      session: session ?? this.session,
      controller: identical(controller, _unset)
          ? this.controller
          : controller as CameraController?,
      nativeController: identical(nativeController, _unset)
          ? this.nativeController
          : nativeController as NativeCameraController?,
      localVideoTrack: identical(localVideoTrack, _unset)
          ? this.localVideoTrack
          : localVideoTrack as VideoTrack?,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      selectedEffectId: selectedEffectId ?? this.selectedEffectId,
      effectsPanelMode: effectsPanelMode ?? this.effectsPanelMode,
      effectsCategoryId: effectsCategoryId ?? this.effectsCategoryId,
      isMirrorEnabled: isMirrorEnabled ?? this.isMirrorEnabled,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isStabilizationEnabled:
          isStabilizationEnabled ?? this.isStabilizationEnabled,
      isNoiseReductionEnabled:
          isNoiseReductionEnabled ?? this.isNoiseReductionEnabled,
      isAiContentTagged: isAiContentTagged ?? this.isAiContentTagged,
      isLivePaused: isLivePaused ?? this.isLivePaused,
      showLiveGiftsBadge: showLiveGiftsBadge ?? this.showLiveGiftsBadge,
      showLiveTitleBadge: showLiveTitleBadge ?? this.showLiveTitleBadge,
      isMediaConnected: isMediaConnected ?? this.isMediaConnected,
      isChatComposerVisible:
          isChatComposerVisible ?? this.isChatComposerVisible,
      isSendingChat: isSendingChat ?? this.isSendingChat,
      isEnding: isEnding ?? this.isEnding,
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      floatingHeartBurst: floatingHeartBurst ?? this.floatingHeartBurst,
      giftBanner: identical(giftBanner, _unset)
          ? this.giftBanner
          : giftBanner as LiveGiftBanner?,
      latestGiftCombo: identical(latestGiftCombo, _unset)
          ? this.latestGiftCombo
          : latestGiftCombo as GiftComboPayload?,
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
      guests: guests ?? this.guests,
      pendingGuestInvite: identical(pendingGuestInvite, _unset)
          ? this.pendingGuestInvite
          : pendingGuestInvite as LivePendingGuestInvite?,
      pendingCompetitionRequest: identical(pendingCompetitionRequest, _unset)
          ? this.pendingCompetitionRequest
          : pendingCompetitionRequest as LiveCompetitionRequest?,
      isCompetitionActionBusy:
          isCompetitionActionBusy ?? this.isCompetitionActionBusy,
      battle: identical(battle, _unset) ? this.battle : battle as LiveBattle?,
      battleMediaRoom: identical(battleMediaRoom, _unset)
          ? this.battleMediaRoom
          : battleMediaRoom as Room?,
      topGifterAvatars: topGifterAvatars ?? this.topGifterAvatars,
      opponentTopGifterAvatars:
          opponentTopGifterAvatars ?? this.opponentTopGifterAvatars,
    );
  }
}

/// An unanswered `liveGuestInvite` for this user, kept in state so the prompt
/// survives a rebuild instead of flashing past in a SnackBar.
class LivePendingGuestInvite {
  const LivePendingGuestInvite({
    required this.liveId,
    required this.hostName,
    required this.role,
  });

  final String liveId;
  final String hostName;
  final String role;

  bool get isCoHost => role.toUpperCase() == 'CO_HOST';
}

class LiveRoomEnded extends LiveRoomState {
  const LiveRoomEnded();
}
