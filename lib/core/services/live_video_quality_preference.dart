import 'package:flutter/foundation.dart';

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

  LiveCaptureProfile _profile = LiveCaptureProfile.preferred;

  LiveCaptureProfile get profile => _profile;

  /// Tiers the host may pick from, highest first.
  List<LiveCaptureProfile> get options => LiveCaptureProfile.ladder;

  void select(LiveCaptureProfile profile) {
    if (_profile == profile) return;
    _profile = profile;
    notifyListeners();
  }
}
