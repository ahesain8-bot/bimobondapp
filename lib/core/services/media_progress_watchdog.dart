/// Detects a media counter that stopped advancing while signalling still says
/// the room is connected.
///
/// WebRTC counters are cumulative. A reset or track replacement can make the
/// value smaller, so any change is treated as healthy and establishes a new
/// baseline. Missing stats are ignored because some platforms expose them only
/// intermittently.
class MediaProgressWatchdog {
  MediaProgressWatchdog({required this.stalledSampleLimit})
    : assert(stalledSampleLimit > 0);

  final int stalledSampleLimit;

  num? _lastProgress;
  int _stalledSamples = 0;
  bool _reported = false;

  bool get hasBaseline => _lastProgress != null;

  /// Returns true once when [progress] has not changed for the configured
  /// number of consecutive samples.
  bool addSample(num? progress) {
    if (progress == null || _reported) return false;
    final previous = _lastProgress;
    if (previous == null || progress != previous) {
      _lastProgress = progress;
      _stalledSamples = 0;
      return false;
    }
    return _markStalledSample();
  }

  /// Counts a missing track as stalled only after real media was seen once.
  bool addMissingTrackSample() {
    if (!hasBaseline || _reported) return false;
    return _markStalledSample();
  }

  bool _markStalledSample() {
    _stalledSamples++;
    if (_stalledSamples < stalledSampleLimit) return false;
    _reported = true;
    return true;
  }

  void reset() {
    _lastProgress = null;
    _stalledSamples = 0;
    _reported = false;
  }
}
