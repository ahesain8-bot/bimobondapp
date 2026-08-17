import 'package:camera/camera.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../domain/effects/live_effects_catalog.dart';
import '../../../domain/entities/live_session.dart';
import 'live_room_event.dart';

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
    this.isCameraInitialized = false,
    this.isFrontCamera = true,
  });

  final CameraController? controller;
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
  });

  final LiveSession session;

  /// Optional Flutter [CameraController] (effects / fallback preview only).
  final CameraController? controller;

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

  LiveRoomReady copyWith({
    LiveSession? session,
    Object? controller = _unset,
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
  }) {
    return LiveRoomReady(
      session: session ?? this.session,
      controller: identical(controller, _unset)
          ? this.controller
          : controller as CameraController?,
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
      actionMessage:
          clearActionMessage ? null : (actionMessage ?? this.actionMessage),
      floatingHeartBurst: floatingHeartBurst ?? this.floatingHeartBurst,
    );
  }
}

class LiveRoomEnded extends LiveRoomState {
  const LiveRoomEnded();
}
