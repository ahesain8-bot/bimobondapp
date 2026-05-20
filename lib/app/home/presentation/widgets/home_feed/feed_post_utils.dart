import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

bool feedPostHasVideo(PostEntity post) {
  if (post.type.toUpperCase() == 'VIDEO') return true;

  final videoUrl = post.videoUrl;
  if (videoUrl != null &&
      videoUrl.isNotEmpty &&
      MediaUtils.isVideo(videoUrl)) {
    return true;
  }

  if (post.media.isEmpty) return false;

  return post.media.any(
    (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
  );
}
