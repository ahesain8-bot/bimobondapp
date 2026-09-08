import 'live_scene.dart';

/// Which outbound LiveKit publications to mute for a temporary LIVE pause,
/// and which to restore on resume.
///
/// Pause is not End LIVE: the room stays connected. Screen share is muted
/// in place (`stopOnMute: false`) so Android MediaProjection is not torn down.
class LiveHostOutboundPausePlan {
  const LiveHostOutboundPausePlan({
    required this.muteCamera,
    required this.muteMicrophone,
    required this.muteScreenShare,
    required this.restoreCamera,
    required this.restoreMicrophone,
    required this.restoreScreenShare,
  });

  /// AUDIO: mic only. CAMERA: camera + mic. SCREEN: screen + mic.
  /// DUAL: camera + screen + mic.
  factory LiveHostOutboundPausePlan.fromSession({
    required bool isAudioOnly,
    required LiveScene scene,
    required bool micWasEnabled,
  }) {
    if (isAudioOnly) {
      return LiveHostOutboundPausePlan(
        muteCamera: false,
        muteMicrophone: true,
        muteScreenShare: false,
        restoreCamera: false,
        restoreMicrophone: micWasEnabled,
        restoreScreenShare: false,
      );
    }
    final restoreCamera = scene.isCamera || scene.isDual;
    final restoreScreen = scene.isScreen || scene.isDual;
    return LiveHostOutboundPausePlan(
      muteCamera: restoreCamera,
      muteMicrophone: true,
      muteScreenShare: restoreScreen,
      restoreCamera: restoreCamera,
      restoreMicrophone: micWasEnabled,
      restoreScreenShare: restoreScreen,
    );
  }

  final bool muteCamera;
  final bool muteMicrophone;
  final bool muteScreenShare;
  final bool restoreCamera;
  final bool restoreMicrophone;
  final bool restoreScreenShare;

  LiveHostOutboundPausePlan copyWith({
    bool? muteCamera,
    bool? muteMicrophone,
    bool? muteScreenShare,
    bool? restoreCamera,
    bool? restoreMicrophone,
    bool? restoreScreenShare,
  }) {
    return LiveHostOutboundPausePlan(
      muteCamera: muteCamera ?? this.muteCamera,
      muteMicrophone: muteMicrophone ?? this.muteMicrophone,
      muteScreenShare: muteScreenShare ?? this.muteScreenShare,
      restoreCamera: restoreCamera ?? this.restoreCamera,
      restoreMicrophone: restoreMicrophone ?? this.restoreMicrophone,
      restoreScreenShare: restoreScreenShare ?? this.restoreScreenShare,
    );
  }
}
