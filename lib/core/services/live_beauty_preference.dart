import 'package:flutter/foundation.dart';

import '../../features/live/data/services/live_beauty_bridge.dart';
import '../../features/live/domain/entities/live_beauty_preset.dart';

/// Host-selected beauty look for the live camera.
///
/// Holds the selection in one place because two screens set it — the go-live
/// sheet and the room's effects panel — and the published track is re-created
/// on every camera flip, so whatever is chosen has to be re-applied to the new
/// track rather than living on it.
///
/// Beauty is on by default: TikTok opens its camera with a light look already
/// applied, and the host's first frame is the one they judge the app on. The
/// default is deliberately gentle — see [LiveBeautyPreset.natural].
class LiveBeautyPreference extends ChangeNotifier {
  LiveBeautyPreference._();

  static final LiveBeautyPreference instance = LiveBeautyPreference._();

  LiveBeautyPreset _preset = LiveBeautyPreset.natural;
  double _intensity = 1.0;

  LiveBeautyPreset get preset => _preset;

  /// Overall strength of [preset], 0…1. Scales every parameter together.
  double get intensity => _intensity;

  bool get isActive => _preset.isActive && _intensity > 0.01;

  List<LiveBeautyPreset> get options => LiveBeautyPreset.catalog;

  /// True once the shader is installed on the published track.
  bool get isAttached => LiveBeautyBridge.attachedTrackId != null;

  void select(LiveBeautyPreset preset) {
    if (_preset.id == preset.id) return;
    _preset = preset;
    notifyListeners();
    _push();
  }

  void setIntensity(double value) {
    final next = value.clamp(0.0, 1.0);
    if ((next - _intensity).abs() < 0.001) return;
    _intensity = next;
    notifyListeners();
    _push();
  }

  /// Installs the shader on a freshly published track and applies the current
  /// look. Called after every publish, including camera flips.
  Future<bool> attachTo(String? trackId) async {
    final attached = await LiveBeautyBridge.attach(trackId);
    if (attached) await _push();
    return attached;
  }

  Future<void> detach() => LiveBeautyBridge.detach();

  Future<void> _push() =>
      LiveBeautyBridge.apply(_preset, intensity: _intensity);
}
