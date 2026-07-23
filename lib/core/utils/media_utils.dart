import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/utils/api_constants.dart';

class MediaUtils {
  MediaUtils._();

  /// Turns API-relative paths (e.g. `/uploads/foo.jpg`) into absolute URLs.
  static String resolveAbsoluteUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('assets/') || trimmed.startsWith('packages/')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '${ApiConstants.baseUrl}$trimmed';
    }
    return '${ApiConstants.baseUrl}/$trimmed';
  }

  static const List<String> videoExtensions = [
    '.mp4',
    '.mov',
    '.avi',
    '.wmv',
    '.flv',
    '.mkv',
    '.webm',
    '.m4v',
    '.3gp',
    '.mpg',
    '.mpeg',
    '.m3u8',
  ];

  static const List<String> imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
    '.heif',
  ];

  /// True only for URLs that look like real image files (not video / unknown).
  static bool isLikelyImageUrl(String url) {
    if (url.isEmpty || isVideo(url)) return false;
    final cleanUrl = url.toLowerCase().split('?').first;
    return imageExtensions.any((ext) => cleanUrl.endsWith(ext));
  }

  /// Primary playable video URL for a post (HLS preferred when available).
  static String? resolveVideoUrl(PostEntity post) {
    final candidates = <String>[];

    final hls = post.hlsUrl;
    if (hls != null && hls.isNotEmpty) {
      candidates.add(resolveAbsoluteUrl(hls));
    }

    final direct = post.videoUrl;
    if (direct != null && direct.isNotEmpty) {
      candidates.add(resolveAbsoluteUrl(direct));
    }

    for (final item in post.media) {
      if (item.url.isEmpty) continue;
      if (item.mediaType.toUpperCase() == 'VIDEO' ||
          isVideo(item.url, mediaType: item.mediaType)) {
        candidates.add(resolveAbsoluteUrl(item.url));
      }
    }

    for (final url in candidates) {
      if (url.isNotEmpty && (isVideo(url) || post.type.toUpperCase() == 'VIDEO')) {
        return url;
      }
    }

    if (post.type.toUpperCase() == 'VIDEO') {
      for (final url in candidates) {
        if (url.isNotEmpty) return url;
      }
    }

    return null;
  }

  /// Feed playback URL that prefers progressive files (MP4/WebM) so scroll
  /// up/down can reuse [AppMediaCacheManager] disk cache. HLS only if needed.
  static String? resolveCacheableFeedVideoUrl(PostEntity post) {
    final progressive = <String>[];

    final direct = post.videoUrl;
    if (direct != null && direct.isNotEmpty) {
      final resolved = resolveAbsoluteUrl(direct);
      if (!_isHlsPath(resolved)) progressive.add(resolved);
    }

    for (final item in post.media) {
      if (item.url.isEmpty) continue;
      if (item.mediaType.toUpperCase() == 'VIDEO' ||
          isVideo(item.url, mediaType: item.mediaType)) {
        final resolved = resolveAbsoluteUrl(item.url);
        if (!_isHlsPath(resolved)) progressive.add(resolved);
      }
    }

    for (final url in progressive) {
      if (url.isNotEmpty) return url;
    }

    final hls = post.hlsUrl;
    if (hls != null && hls.isNotEmpty) {
      return resolveAbsoluteUrl(hls);
    }
    return null;
  }

  static bool _isHlsPath(String url) {
    return url.toLowerCase().split('?').first.endsWith('.m3u8');
  }

  /// Poster image for a video post (API thumbnail or first image in media).
  static String? resolveVideoPosterUrl(PostEntity post) {
    final videoUrl = resolveVideoUrl(post);

    final thumb = post.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      final resolved = resolveAbsoluteUrl(thumb);
      if (videoUrl == null || resolved != videoUrl) {
        if (!isVideo(resolved)) return resolved;
      }
    }

    for (final item in post.media) {
      if (item.mediaType.toUpperCase() == 'IMAGE' && item.url.isNotEmpty) {
        final resolved = resolveAbsoluteUrl(item.url);
        if (!isVideo(resolved)) return resolved;
      }
    }

    return null;
  }

  /// Cover image for feed cards, promotions, auctions, and profile grids.
  static String? resolvePostCoverUrl(PostEntity post) {
    if (post.isAuctionable) {
      final auctionImage = post.auction?.itemImageUrl;
      if (auctionImage != null && auctionImage.isNotEmpty) {
        return resolveAbsoluteUrl(auctionImage);
      }
    }

    final poster = resolveVideoPosterUrl(post);
    if (poster != null && poster.isNotEmpty) return poster;

    for (final item in post.media) {
      if (item.url.isEmpty) continue;
      if (isImage(item.url, mediaType: item.mediaType)) {
        return resolveAbsoluteUrl(item.url);
      }
    }

    final thumb = post.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty && !isVideo(thumb)) {
      return resolveAbsoluteUrl(thumb);
    }

    return null;
  }

  /// Checks if a URL points to a video based on extension or metadata
  static bool isVideo(String url, {String? mediaType}) {
    if (url.isEmpty) return false;

    // 1. Check explicit metadata if provided
    if (mediaType?.toUpperCase() == 'VIDEO') return true;

    // 2. Check URL content
    final lowerUrl = url.toLowerCase();

    // Handle Firebase/Cloud storage URLs with query params
    final cleanUrl = lowerUrl.split('?').first;

    // Image extensions win over path keywords like "/video/" in the URL.
    if (imageExtensions.any((ext) => cleanUrl.endsWith(ext))) return false;

    // Check extensions
    if (videoExtensions.any((ext) => cleanUrl.endsWith(ext))) return true;

    // HLS manifests and stream paths
    if (lowerUrl.contains('.m3u8')) return true;

    // Fallback: check if URL contains common video identifiers (less reliable but useful for streams)
    if (lowerUrl.contains('video') || lowerUrl.contains('mp4')) return true;

    return false;
  }

  /// Checks if a URL points to an image
  static bool isImage(String url, {String? mediaType}) {
    if (url.isEmpty) return false;

    if (mediaType?.toUpperCase() == 'VIDEO') return false;

    // 1. Check explicit metadata if provided
    if (mediaType?.toUpperCase() == 'IMAGE') return true;

    // 2. Check URL content
    final lowerUrl = url.toLowerCase();
    final cleanUrl = lowerUrl.split('?').first;

    // Check extensions
    if (imageExtensions.any((ext) => cleanUrl.endsWith(ext))) return true;

    // If it's not a video and has some common image keywords or is a typical media URL
    if (!isVideo(url, mediaType: mediaType)) {
      // If we can't tell, we often assume image for fallback if it's not obviously a video
      return true;
    }

    return false;
  }
}
