/// A kept portion of a source video's timeline, expressed as a [start]…[end]
/// range into the original clip. A video with an empty segment list means "the
/// whole clip"; otherwise the export keeps only these ranges, in order, which is
/// how trimming, splitting and deleting parts are represented.
class VideoTrimSegment {
  const VideoTrimSegment({required this.start, required this.end});

  final Duration start;
  final Duration end;

  Duration get duration => end - start;

  VideoTrimSegment copyWith({Duration? start, Duration? end}) =>
      VideoTrimSegment(start: start ?? this.start, end: end ?? this.end);

  Map<String, int> toMap() => {
        'start': start.inMilliseconds,
        'end': end.inMilliseconds,
      };

  factory VideoTrimSegment.fromMap(Map<String, dynamic> map) => VideoTrimSegment(
        start: Duration(milliseconds: (map['start'] as num?)?.toInt() ?? 0),
        end: Duration(milliseconds: (map['end'] as num?)?.toInt() ?? 0),
      );

  @override
  bool operator ==(Object other) =>
      other is VideoTrimSegment && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'VideoTrimSegment(${start.inMilliseconds}..'
      '${end.inMilliseconds}ms)';
}

/// Whether [segments] represent an actual edit versus the untouched full clip.
bool videoSegmentsAreTrimmed(
  List<VideoTrimSegment> segments,
  Duration fullDuration,
) {
  if (segments.isEmpty) return false;
  if (segments.length > 1) return true;
  final only = segments.first;
  const tolerance = Duration(milliseconds: 120);
  final startTrimmed = only.start > tolerance;
  final endTrimmed = (fullDuration - only.end) > tolerance;
  return startTrimmed || endTrimmed;
}
