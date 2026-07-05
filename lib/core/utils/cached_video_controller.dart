import 'dart:async';
import 'dart:io';

import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Creates a [VideoPlayerController] for a remote URL.
///
/// Plays immediately over the network. Uses a cached file only when it is
/// already on disk; full downloads are prefetched in the background.
Future<VideoPlayerController> createCachedVideoController(
  String url, {
  VideoPlayerOptions? videoPlayerOptions,
}) async {
  final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
  final options = videoPlayerOptions ??
      VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      );

  if (resolved.isEmpty) {
    throw ArgumentError('Video URL is empty');
  }

  if (kIsWeb || resolved.toLowerCase().contains('.m3u8')) {
    return VideoPlayerController.networkUrl(
      Uri.parse(resolved),
      videoPlayerOptions: options,
    );
  }

  if (!kIsWeb) {
    try {
      final cached = await AppMediaCacheManager.instance.getFileFromCache(
        resolved,
      );
      if (cached != null && await cached.file.exists()) {
        return VideoPlayerController.file(cached.file, videoPlayerOptions: options);
      }
    } catch (error) {
      debugPrint('Video cache lookup failed for $resolved: $error');
    }

    unawaited(_prefetchVideoInBackground(resolved));
  }

  return VideoPlayerController.networkUrl(
    Uri.parse(resolved),
    videoPlayerOptions: options,
  );
}

Future<void> _prefetchVideoInBackground(String url) async {
  try {
    await AppMediaCacheManager.instance.downloadFile(url);
  } catch (_) {
    // Best-effort cache; playback already uses network streaming.
  }
}

/// Returns a cached local file for a remote video URL, if available.
Future<File?> cachedVideoFile(String url) async {
  if (kIsWeb) return null;
  try {
    final resolved = MediaUtils.resolveAbsoluteUrl(url.trim());
    final cached = await AppMediaCacheManager.instance.getFileFromCache(
      resolved,
    );
    return cached?.file;
  } catch (_) {
    return null;
  }
}
