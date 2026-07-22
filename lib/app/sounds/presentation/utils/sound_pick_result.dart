import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';

/// Result of [SoundPickerSheet]: chosen track, optional trim, or clear.
class SoundPickResult {
  const SoundPickResult({
    required SoundEntity this.sound,
    this.offset = Duration.zero,
    this.window = const Duration(seconds: 15),
    this.muteOriginal = false,
    this.didTrim = false,
    this.needsTrim = false,
    this.soundSegmentId,
  }) : cleared = false;

  /// User chose to remove the currently selected music.
  const SoundPickResult.cleared()
      : sound = null,
        offset = Duration.zero,
        window = const Duration(seconds: 15),
        muteOriginal = false,
        didTrim = false,
        needsTrim = false,
        soundSegmentId = null,
        cleared = true;

  final SoundEntity? sound;
  final Duration offset;

  /// Selected period length (default 15s TikTok-style clip).
  final Duration window;

  final bool muteOriginal;

  /// True when the user confirmed via the trim sheet (scissors → check).
  final bool didTrim;

  /// Internal: scissors was tapped; [SoundPickerSheet.show] should open trim
  /// after the catalog sheet closes (avoids nested modal apply bugs).
  final bool needsTrim;

  /// Optional pre-resolved segment id from the API.
  final String? soundSegmentId;

  /// True when the user removed music instead of picking a track.
  final bool cleared;

  /// Attach range for post/story create (`endMs` exclusive).
  ({int startMs, int endMs})? get clipRangeMs {
    final s = sound;
    if (s == null || cleared) return null;
    return SoundEntity.clipRangeMs(
      durationSeconds: s.duration,
      offset: offset,
      window: window,
    );
  }
}
