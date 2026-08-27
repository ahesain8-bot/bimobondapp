// `AudioManager`'s session-management API is marked @experimental by
// livekit_client 2.11.0, but it is the only supported way to stop a second
// Room's teardown from tearing down the whole process's Android audio session
// — see the class doc below. Pin the SDK version before upgrading.
// ignore_for_file: experimental_member_use

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

/// Owns the process-wide Android audio session for as long as a live room is
/// on screen, so a second LiveKit [Room] cannot silence the first one.
///
/// LiveKit's Android audio session is global to the app **and not reference
/// counted**: every `Room._cleanUp()` (any `disconnect()` / `dispose()`) calls
/// `NativeAudioManagement.stop()` → `stopAndroidAudioSession()`, which makes
/// `LKAudioSwitchManager` abandon audio focus and drop its `AudioSwitch`
/// outright — for *every* room in the process, not just the one closing.
///
/// A PK battle runs a second Room (the opponent's) beside the primary one.
/// Tearing that battle room down — when the battle ends, on a battle-room
/// reconnect, or when two `liveBattle` events race the connect — therefore
/// killed the audio of the live that was still connected. That is why the two
/// competing hosts stopped hearing each other and viewers lost audio outright.
///
/// Under [AudioSessionManagementMode.manual] that teardown becomes a no-op on
/// Android (`NativeAudioManagement.stop` skips manual mode), so the session
/// survives battle-room churn. Ownership is handed back to LiveKit in
/// [release], which must run *before* the last room disconnects so the SDK's
/// own automatic teardown is the thing that finally frees the session.
///
/// iOS is deliberately untouched: `NativeAudioManagement.stop()` is
/// Android-only, so iOS never had this bug, and taking the Apple session off
/// LiveKit's engine-driven automatic management would only risk breaking it.
class LiveAudioSession {
  LiveAudioSession._();

  static final LiveAudioSession instance = LiveAudioSession._();

  /// Number of live media stacks (host / viewer) currently holding the session.
  int _holders = 0;

  /// Whether manual mode is currently ours to hand back.
  bool _owned = false;

  static bool get _appliesToPlatform => !kIsWeb && Platform.isAndroid;

  @visibleForTesting
  int get holderCount => _holders;

  /// Takes ownership of the audio session. Call **before** connecting the first
  /// [Room] of a live. Safe to nest — the session is configured once.
  Future<void> acquire() async {
    if (!_appliesToPlatform) return;
    _holders++;
    if (_owned) return;
    try {
      // Entering manual mode and applying the policy in one call: this
      // configures *and* starts the native Android session (the plugin's
      // `configureAndroidAudioSession` handler calls `start()` itself).
      await AudioManager.instance.setAudioSessionOptions(
        const AudioSessionOptions.communication(),
      );
      // Live rooms are media playback, not private calls: keep a headset or
      // Bluetooth device first, otherwise route to the loudspeaker.
      await AudioManager.instance.setSpeakerOutputPreferred(true, force: false);
      _owned = true;
      debugPrint('🔊 [LiveAudioSession] acquired (manual mode, holders=$_holders)');
    } catch (error, stack) {
      _holders = _holders > 0 ? _holders - 1 : 0;
      // Falling back to LiveKit's automatic management is worse than owning
      // the session, but it is not worse than failing to connect at all.
      debugPrint('🔴 [LiveAudioSession] acquire failed: $error\n$stack');
    }
  }

  /// Hands the session back to LiveKit's automatic management.
  ///
  /// Call this **before** disconnecting the last room of the live: restoring
  /// automatic mode re-applies the policy (the session stays up for a moment),
  /// and the room teardown that follows is then the call that releases it. A
  /// battle room closing while the primary room is still connected must never
  /// reach here — that is exactly the case this class exists to survive.
  Future<void> release() async {
    if (!_appliesToPlatform) return;
    if (_holders > 0) _holders--;
    if (_holders > 0 || !_owned) return;
    _owned = false;
    try {
      await AudioManager.instance.setAudioSessionManagementMode(
        AudioSessionManagementMode.automatic,
      );
      debugPrint('🔊 [LiveAudioSession] released back to automatic management');
    } catch (error, stack) {
      debugPrint('🔴 [LiveAudioSession] release failed: $error\n$stack');
    }
  }
}
