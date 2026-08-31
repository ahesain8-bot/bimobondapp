import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/live/domain/entities/live_capture_profile.dart';

/// Host-selected ceiling for the live video pipeline.
///
/// Holds the *ceiling*, never a promise: both the local preview and the
/// LiveKit publisher still walk down from here until the hardware accepts a
/// profile, so a handset that cannot sustain 1080p quietly lands on 720p
/// instead of advertising a layer it never produced.
class LiveVideoQualityPreference extends ChangeNotifier {
  LiveVideoQualityPreference._();

  static final LiveVideoQualityPreference instance =
      LiveVideoQualityPreference._();

  static const _channel = MethodChannel('com.dubai.bimobondapp/ar_camera');

  LiveCaptureProfile _profile = LiveCaptureProfile.preferred;

  LiveCaptureProfile get profile => _profile;

  /// True once [resolveDeviceDefault] has run, whatever it decided.
  var _resolved = false;

  /// Set when the host picks a tier by hand, so a later capability probe
  /// cannot quietly overrule a deliberate choice.
  var _chosenByHost = false;

  /// Tiers the host may pick from, highest first.
  List<LiveCaptureProfile> get options => LiveCaptureProfile.ladder;

  /// Raises the default to 1080p on hardware that can actually sustain it.
  ///
  /// Starts from [LiveCaptureProfile.preferred] (720p) and only moves up, so
  /// the failure mode of the probe — an exception, a missing channel, an
  /// unknown platform — is the safe tier rather than the expensive one. Call
  /// it once before a broadcast starts; it is a no-op afterwards.
  Future<void> resolveDeviceDefault() async {
    if (_resolved || _chosenByHost) return;
    _resolved = true;
    if (!Platform.isAndroid) return;
    try {
      final allowed =
          await _channel.invokeMethod<bool>('allowsFullHdLive') ?? false;
      if (allowed && !_chosenByHost) {
        _profile = LiveCaptureProfile.fullHd;
        notifyListeners();
      }
    } catch (_) {
      // Stay at 720p. A handset whose capability we cannot read is exactly
      // the handset not to gamble a broadcast on.
    }
  }

  void select(LiveCaptureProfile profile) {
    _chosenByHost = true;
    if (_profile == profile) return;
    _profile = profile;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _profile = LiveCaptureProfile.preferred;
    _resolved = false;
    _chosenByHost = false;
  }
}
