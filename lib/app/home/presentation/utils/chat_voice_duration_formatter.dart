String formatVoiceDurationLabel(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = safeSeconds ~/ 60;
  final seconds = safeSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatVoiceDurationFromContent(String? raw) {
  final parsed = int.tryParse(raw ?? '');
  if (parsed == null) return '0:00';
  return formatVoiceDurationLabel(parsed);
}
