import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';

typedef FeedPostPatch =
    void Function(String postId, PostEntity Function(PostEntity post) patch);

bool feedPostEngagementChanged(PostEntity a, PostEntity b) {
  return a.isLiked != b.isLiked ||
      a.likeCount != b.likeCount ||
      a.commentCount != b.commentCount ||
      a.isSaved != b.isSaved ||
      a.saveCount != b.saveCount ||
      a.isReposted != b.isReposted ||
      a.repostCount != b.repostCount;
}

PostEntity patchFeedPostLike(PostEntity post, {required bool liked}) {
  final wasLiked = post.isLiked;
  var count = post.likeCount;
  if (liked && !wasLiked) count++;
  if (!liked && wasLiked && count > 0) count--;
  return post.copyWith(isLiked: liked, likeCount: count);
}

PostEntity patchFeedPostSaveToggle(PostEntity post) {
  final nextSaved = !post.isSaved;
  var count = post.saveCount;
  if (nextSaved && !post.isSaved) count++;
  if (!nextSaved && post.isSaved && count > 0) count--;
  return post.copyWith(isSaved: nextSaved, saveCount: count);
}

PostEntity patchFeedPostRepost(PostEntity post, {required bool isReposted}) {
  final wasReposted = post.isReposted;
  var count = post.repostCount;
  if (isReposted && !wasReposted) count++;
  if (!isReposted && wasReposted && count > 0) count--;
  return post.copyWith(isReposted: isReposted, repostCount: count);
}

bool feedPostHasVideo(PostEntity post) {
  if (post.type.toUpperCase() == 'VIDEO') return true;

  final videoUrl = post.videoUrl;
  if (videoUrl != null && videoUrl.isNotEmpty && MediaUtils.isVideo(videoUrl)) {
    return true;
  }

  if (post.media.isEmpty) return false;

  return post.media.any(
    (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
  );
}

bool feedPostHasImage(PostEntity post) {
  if (post.isAuctionable || feedPostHasVideo(post)) return false;
  if (post.type.toUpperCase() == 'IMAGE') return true;
  if (post.media.isEmpty) return false;
  return post.media.any(
    (m) =>
        m.url.isNotEmpty && !MediaUtils.isVideo(m.url, mediaType: m.mediaType),
  );
}

/// Search chrome on profile fullscreen (video progress or photo search row only).
bool feedPostShowsProfileSearchChrome(PostEntity post) {
  if (post.isAuctionable) return false;
  return feedPostHasVideo(post) || feedPostHasImage(post);
}
