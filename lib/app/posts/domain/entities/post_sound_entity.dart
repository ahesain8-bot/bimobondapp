import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:equatable/equatable.dart';

class PostSoundEntity extends Equatable {
  const PostSoundEntity({
    required this.id,
    required this.name,
    this.author,
    this.coverUrl,
    this.duration,
    this.useCount,
    this.audioUrl,
    this.segmentId,
    this.startMs,
    this.endMs,
  });

  final String id;
  final String name;
  final String? author;
  final String? coverUrl;
  final int? duration;
  final int? useCount;
  final String? audioUrl;

  /// Attached clip id (`post.soundSegment.id`) when known — Mode A reuse.
  final String? segmentId;

  /// Inclusive start of the attached clip on [audioUrl].
  final int? startMs;

  /// Exclusive end of the attached clip on [audioUrl].
  final int? endMs;

  String? get resolvedAudioUrl {
    final url = audioUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  String? get resolvedCoverUrl {
    final url = coverUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  /// True when playback should seek/loop within [startMs, endMs).
  bool get hasSegmentWindow {
    final start = startMs;
    final end = endMs;
    return start != null && end != null && end > start;
  }

  factory PostSoundEntity.fromJson(Map<String, dynamic> json) {
    String? author = json['author']?.toString();
    if (author == null || author.isEmpty) {
      final creator = json['creator'];
      if (creator is Map) {
        author = (creator['fullName'] ?? creator['username'])?.toString();
      }
    }

    return PostSoundEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      author: author,
      coverUrl: json['coverUrl']?.toString() ?? json['iconUrl']?.toString(),
      duration: json['duration'] is int
          ? json['duration'] as int
          : int.tryParse(json['duration']?.toString() ?? ''),
      useCount: json['useCount'] is int
          ? json['useCount'] as int
          : int.tryParse(json['useCount']?.toString() ?? ''),
      audioUrl: json['audioUrl']?.toString(),
      segmentId: json['segmentId']?.toString() ?? json['soundSegmentId']?.toString(),
      startMs: json['startMs'] is int
          ? json['startMs'] as int
          : int.tryParse(json['startMs']?.toString() ?? ''),
      endMs: json['endMs'] is int
          ? json['endMs'] as int
          : int.tryParse(json['endMs']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        author,
        coverUrl,
        duration,
        useCount,
        audioUrl,
        segmentId,
        startMs,
        endMs,
      ];
}
