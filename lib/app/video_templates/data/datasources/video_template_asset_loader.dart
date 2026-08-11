import 'dart:io';

import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:flutter/foundation.dart';

/// Lazy disk cache for template media URLs (LUT / sticker / overlay / preview).
///
/// Does **not** download the full asset pack on recipe fetch — only when asked.
class VideoTemplateAssetLoader {
  VideoTemplateAssetLoader();

  /// Resolved absolute URL → local file (in-memory index of this session).
  final Map<String, File> _sessionFiles = {};

  /// Cover + preview only (cheap; safe after user opens template detail).
  Future<VideoTemplatePreviewAssets> prefetchPreview(
    VideoTemplateRecipeEntity recipe, {
    VideoTemplateCardEntity? card,
  }) async {
    final coverUrl = recipe.coverUrl ?? card?.coverUrl;
    final previewUrl = recipe.previewVideoUrl ?? card?.previewVideoUrl;

    final coverFuture = (coverUrl != null && coverUrl.trim().isNotEmpty)
        ? ensureUrl(coverUrl, preferVideoCache: false)
        : Future<File?>.value(null);
    final previewFuture = (previewUrl != null && previewUrl.trim().isNotEmpty)
        ? ensureUrl(previewUrl, preferVideoCache: true)
        : Future<File?>.value(null);
    final results = await Future.wait([coverFuture, previewFuture]);
    return VideoTemplatePreviewAssets(
      coverFile: results[0],
      previewVideoFile: results[1],
      coverUrl: coverUrl,
      previewVideoUrl: previewUrl,
    );
  }

  /// Downloads assets needed to *edit* (stickers, overlays, LUT filters, fonts).
  /// Slot placeholders are optional ([includePlaceholders]).
  Future<Map<String, File>> prefetchEditorAssets(
    VideoTemplateRecipeEntity recipe, {
    bool includePlaceholders = false,
    bool includePreview = true,
  }) async {
    final urls = collectEditorAssetUrls(
      recipe,
      includePlaceholders: includePlaceholders,
      includePreview: includePreview,
    );
    final files = await Future.wait(
      urls.map(
        (url) => ensureUrl(url, preferVideoCache: _looksLikeVideo(url)),
      ),
    );
    final out = <String, File>{};
    var i = 0;
    for (final url in urls) {
      final file = files[i++];
      if (file != null) out[url] = file;
    }
    return out;
  }

  /// Single-URL lazy fetch. Returns cached file when already on disk.
  Future<File?> ensureUrl(
    String rawUrl, {
    bool preferVideoCache = false,
  }) async {
    if (kIsWeb) return null;
    final url = MediaUtils.resolveAbsoluteUrl(rawUrl.trim());
    if (url.isEmpty) return null;
    if (_sessionFiles[url] != null && await _sessionFiles[url]!.exists()) {
      return _sessionFiles[url];
    }

    try {
      File? file;
      if (preferVideoCache || _looksLikeVideo(url) || _looksLikeAudio(url)) {
        file = await AppMediaCacheManager.getCachedVideoFile(url) ??
            await AppMediaCacheManager.downloadVideoFile(url);
      }
      file ??= await AppMediaCacheManager.getCachedFile(url);
      if (await file.exists()) {
        _sessionFiles[url] = file;
        return file;
      }
    } catch (_) {}
    return null;
  }

  Future<File?> ensureAsset(TemplateAssetEntity asset) {
    final preferVideo = asset.type.toUpperCase() == TemplateAssetTypes.video ||
        asset.type.toUpperCase() == TemplateAssetTypes.audio;
    return ensureUrl(asset.url, preferVideoCache: preferVideo);
  }

  /// Unique remote URLs required for editor composition (not user slot media).
  static Set<String> collectEditorAssetUrls(
    VideoTemplateRecipeEntity recipe, {
    bool includePlaceholders = false,
    bool includePreview = true,
  }) {
    final urls = <String>{};

    void add(String? u) {
      final t = u?.trim();
      if (t != null && t.isNotEmpty) urls.add(t);
    }

    if (includePreview) {
      add(recipe.coverUrl);
      add(recipe.previewVideoUrl);
    }

    for (final a in recipe.assets) {
      add(a.url);
      add(a.thumbnailUrl);
    }
    for (final clip in recipe.clips) {
      add(clip.asset?.url);
      add(clip.asset?.thumbnailUrl);
    }
    for (final s in recipe.stickers) {
      add(s.assetUrl);
      add(s.asset?.url);
    }
    for (final o in recipe.overlays) {
      add(o.assetUrl);
      add(o.asset?.url);
    }
    for (final t in recipe.texts) {
      add(t.fontAsset?.url);
    }
    for (final slot in recipe.slots) {
      for (final f in slot.filters) {
        add(f.lutAsset?.url);
      }
      if (includePlaceholders) add(slot.placeholderUrl);
    }
    for (final clip in recipe.clips) {
      for (final f in clip.filters) {
        add(f.lutAsset?.url);
      }
    }
    add(recipe.sound?.audioUrl);
    add(recipe.music?.audioUrl);

    return urls;
  }

  void clearSession() => _sessionFiles.clear();

  static bool _looksLikeVideo(String url) {
    final path = url.toLowerCase().split('?').first;
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm') ||
        path.endsWith('.mkv');
  }

  static bool _looksLikeAudio(String url) {
    final path = url.toLowerCase().split('?').first;
    return path.endsWith('.mp3') ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.wav') ||
        path.endsWith('.ogg');
  }
}

class VideoTemplatePreviewAssets {
  const VideoTemplatePreviewAssets({
    this.coverFile,
    this.previewVideoFile,
    this.coverUrl,
    this.previewVideoUrl,
  });

  final File? coverFile;
  final File? previewVideoFile;
  final String? coverUrl;
  final String? previewVideoUrl;

  bool get hasCover => coverFile != null;
  bool get hasPreviewVideo => previewVideoFile != null;
}
