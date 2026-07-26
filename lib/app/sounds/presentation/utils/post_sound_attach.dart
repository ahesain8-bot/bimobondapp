import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';

/// Resolves mutually exclusive sound fields for `POST /posts` / stories.
///
/// See `post-sounds.md`:
/// - Mode A: `soundSegmentId` alone (known clip / “use this sound”)
/// - Mode B: `soundId` (+ optional `startMs`/`endMs` for custom trim)
/// - Mode C: `newSound` (handled separately when no library sound)
class PostSoundAttach {
  PostSoundAttach._();

  /// Mode A — attach an existing segment only.
  static PostSoundAttachParams fromSegment(String soundSegmentId) {
    final id = soundSegmentId.trim();
    if (id.isEmpty) return const PostSoundAttachParams();
    return PostSoundAttachParams(soundSegmentId: id);
  }

  /// Mode B — library / trending track.
  ///
  /// Always includes [startMs] and [endMs]: defaults to 0..15000ms (or track length)
  /// when not trimmed, or custom range when trimmed.
  static PostSoundAttachParams fromLibrary(
    SoundEntity sound, {
    Duration offset = Duration.zero,
    Duration window = const Duration(seconds: 15),
    bool didTrim = false,
  }) {
    final id = sound.id.trim();
    if (id.isEmpty) return const PostSoundAttachParams();

    final clip = SoundEntity.clipRangeMs(
      durationSeconds: sound.duration,
      offset: offset,
      window: window,
    );
    return PostSoundAttachParams(
      soundId: id,
      startMs: clip.startMs,
      endMs: clip.endMs,
    );
  }

  /// Prefer Mode A when [soundSegmentId] is set and there is no custom trim;
  /// otherwise Mode B from [sound].
  static PostSoundAttachParams resolve({
    SoundEntity? sound,
    String? soundSegmentId,
    Duration offset = Duration.zero,
    Duration window = const Duration(seconds: 15),
    bool didTrim = false,
  }) {
    final segmentId = soundSegmentId?.trim();
    if (segmentId != null &&
        segmentId.isNotEmpty &&
        !didTrim &&
        offset <= Duration.zero) {
      return fromSegment(segmentId);
    }
    if (sound != null) {
      return fromLibrary(
        sound,
        offset: offset,
        window: window,
        didTrim: didTrim,
      );
    }
    return const PostSoundAttachParams();
  }
}

class PostSoundAttachParams {
  const PostSoundAttachParams({
    this.soundId,
    this.soundSegmentId,
    this.startMs,
    this.endMs,
    this.newSound,
  });

  final String? soundId;
  final String? soundSegmentId;
  final int? startMs;
  final int? endMs;
  final Map<String, dynamic>? newSound;

  bool get hasAttachment =>
      (soundId != null && soundId!.isNotEmpty) ||
      (soundSegmentId != null && soundSegmentId!.isNotEmpty) ||
      newSound != null;
}
