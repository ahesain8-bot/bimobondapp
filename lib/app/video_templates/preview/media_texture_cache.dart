import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/video_templates/preview/template_preview_perf.dart';
import 'package:flutter/foundation.dart';

/// Decodes user stills once at preview resolution and keeps the GPU-ready
/// [ui.Image] alive across template switches.
class MediaTextureCache {
  /// Long-edge target for soft editor preview (not export 1080).
  static const defaultPreviewMaxWidth = 540;

  /// Process-wide soft-preview still cache (survives Template A→B→C).
  static final MediaTextureCache shared = MediaTextureCache();

  MediaTextureCache({
    this.previewMaxWidth = defaultPreviewMaxWidth,
    this.maxEntries = 8,
  });

  final int previewMaxWidth;
  final int maxEntries;

  final Map<String, _CachedStill> _stills = {};
  final Map<String, Future<ui.Image?>> _inflight = {};

  String _key(File file, int maxWidth) => '${file.absolute.path}@$maxWidth';

  ui.Image? peek(File file, {int? maxWidth}) {
    final w = maxWidth ?? previewMaxWidth;
    return _stills[_key(file, w)]?.image;
  }

  Future<ui.Image?> obtain(File file, {int? maxWidth}) {
    final w = maxWidth ?? previewMaxWidth;
    final key = _key(file, w);
    final hit = _stills[key];
    if (hit != null) {
      hit.lastUsed = DateTime.now();
      return Future<ui.Image?>.value(hit.image);
    }
    final pending = _inflight[key];
    if (pending != null) return pending;

    final future = _decode(file, w, key);
    _inflight[key] = future;
    return future.whenComplete(() => _inflight.remove(key));
  }

  Future<ui.Image?> _decode(File file, int maxWidth, String key) async {
    final sw = TemplatePreviewPerf.start();
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxWidth > 0 ? maxWidth : null,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      TemplatePreviewPerf.end(
        sw,
        'decode',
        detail: '${image.width}x${image.height}',
      );

      _evictIfNeeded();
      final prev = _stills.remove(key);
      prev?.image.dispose();
      _stills[key] = _CachedStill(image);
      return image;
    } catch (e, st) {
      debugPrint('MediaTextureCache.obtain failed: $e\n$st');
      TemplatePreviewPerf.end(sw, 'decode', detail: 'error');
      return null;
    }
  }

  void _evictIfNeeded() {
    while (_stills.length >= maxEntries) {
      String? oldestKey;
      DateTime? oldest;
      for (final e in _stills.entries) {
        if (oldest == null || e.value.lastUsed.isBefore(oldest)) {
          oldest = e.value.lastUsed;
          oldestKey = e.key;
        }
      }
      if (oldestKey == null) break;
      _stills.remove(oldestKey)?.image.dispose();
    }
  }

  void retainPaths(Iterable<String> keepPaths) {
    final keep = keepPaths.toSet();
    final toRemove = <String>[];
    for (final key in _stills.keys) {
      final path = key.split('@').first;
      if (!keep.contains(path)) toRemove.add(key);
    }
    for (final key in toRemove) {
      _stills.remove(key)?.image.dispose();
    }
  }

  void clear() {
    for (final e in _stills.values) {
      e.image.dispose();
    }
    _stills.clear();
    _inflight.clear();
  }
}

class _CachedStill {
  _CachedStill(this.image) : lastUsed = DateTime.now();

  final ui.Image image;
  DateTime lastUsed;
}
