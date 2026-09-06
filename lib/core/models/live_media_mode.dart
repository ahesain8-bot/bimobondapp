/// Stored `mediaMode` for a live (`VIDEO` | `AUDIO`).
///
/// Create/query aliases `VOICE` / `SOUND` are stored as `AUDIO`
/// (lives/live-audio-rooms.md).
class LiveMediaMode {
  const LiveMediaMode._();

  static const video = 'VIDEO';
  static const audio = 'AUDIO';

  static String normalize(String? raw) {
    final value = raw?.toUpperCase().trim();
    if (value == audio || value == 'VOICE' || value == 'SOUND') {
      return audio;
    }
    return video;
  }

  static bool isAudio({String? mediaMode, bool audioOnly = false}) {
    if (audioOnly) return true;
    return normalize(mediaMode) == audio;
  }
}
