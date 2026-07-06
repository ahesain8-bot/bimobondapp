import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:equatable/equatable.dart';

class PostSoundEntity extends Equatable {
  const PostSoundEntity({
    required this.id,
    required this.name,
    this.author,
    this.duration,
    this.useCount,
    this.audioUrl,
  });

  final String id;
  final String name;
  final String? author;
  final int? duration;
  final int? useCount;
  final String? audioUrl;

  String? get resolvedAudioUrl {
    final url = audioUrl;
    if (url == null || url.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(url);
  }

  factory PostSoundEntity.fromJson(Map<String, dynamic> json) {
    return PostSoundEntity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      author: json['author']?.toString(),
      duration: json['duration'] is int
          ? json['duration'] as int
          : int.tryParse(json['duration']?.toString() ?? ''),
      useCount: json['useCount'] is int
          ? json['useCount'] as int
          : int.tryParse(json['useCount']?.toString() ?? ''),
      audioUrl: json['audioUrl']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, author, duration, useCount, audioUrl];
}
