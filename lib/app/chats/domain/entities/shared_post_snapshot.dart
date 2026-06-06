import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:equatable/equatable.dart';

/// Lightweight post/story preview attached to a chat message.
class SharedPostSnapshot extends Equatable {
  const SharedPostSnapshot({
    required this.postId,
    this.thumbnailUrl,
    this.mediaUrl,
    this.type = 'IMAGE',
    this.isStory = false,
    this.description,
  });

  final String postId;
  final String? thumbnailUrl;
  final String? mediaUrl;
  final String type;
  final bool isStory;
  final String? description;

  factory SharedPostSnapshot.fromPost(PostEntity post) {
    String? thumb = post.thumbnailUrl;
    String? media = post.videoUrl;
    if (post.media.isNotEmpty) {
      media ??= post.media.first.url;
      thumb ??= post.media.first.url;
    }
    if (post.type == 'VIDEO') {
      thumb ??= post.thumbnailUrl;
      media ??= post.videoUrl ?? '';
    }
    return SharedPostSnapshot(
      postId: post.id,
      thumbnailUrl: thumb,
      mediaUrl: media ?? thumb,
      type: post.type,
      isStory: post.isStory,
      description: post.description,
    );
  }

  factory SharedPostSnapshot.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id'] ?? '').toString();
    String? thumb = json['thumbnailUrl']?.toString();
    String? media = json['videoUrl']?.toString() ?? json['hlsUrl']?.toString();
    final mediaList = json['media'];
    if (mediaList is List && mediaList.isNotEmpty) {
      final first = mediaList.first;
      if (first is Map) {
        final url = first['url']?.toString();
        media ??= url;
        thumb ??= url;
      }
    }
    return SharedPostSnapshot(
      postId: id,
      thumbnailUrl: thumb,
      mediaUrl: media ?? thumb,
      type: json['type']?.toString() ?? 'IMAGE',
      isStory: json['isStory'] == true || json['isStory']?.toString() == 'true',
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toUiMap() {
    final previewUrl = _previewImageUrl;
    return {
      'postId': postId,
      'type': type,
      'isStory': isStory,
      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
        'thumbnailUrl': thumbnailUrl,
      if (previewUrl != null) 'imageUrl': previewUrl,
      if (description != null && description!.trim().isNotEmpty)
        'description': description!.trim(),
    };
  }

  String? get _previewImageUrl {
    final raw = thumbnailUrl ?? mediaUrl;
    if (raw == null || raw.isEmpty) return null;
    return MediaUtils.resolveAbsoluteUrl(raw);
  }

  @override
  List<Object?> get props => [
    postId,
    thumbnailUrl,
    mediaUrl,
    type,
    isStory,
    description,
  ];
}
