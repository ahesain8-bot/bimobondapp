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
  /// Full track → `soundId` only.
  /// User trimmed → `soundId` + `startMs`/`endMs` (never with soundSegmentId).
  static PostSoundAttachParams fromLibrary(
    SoundEntity sound, {
    Duration offset = Duration.zero,
    Duration window = const Duration(seconds: 15),
    bool didTrim = false,
  }) {
    final id = sound.id.trim();
    if (id.isEmpty) return const PostSoundAttachParams();

    // Mode B2 only when the user explicitly trimmed (or restored a non-zero
    // offset). A default 15s picker window must not become startMs/endMs.
    final customClip = didTrim || offset > Duration.zero;

    if (customClip) {
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

    return PostSoundAttachParams(soundId: id);
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
