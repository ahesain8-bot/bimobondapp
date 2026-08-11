import 'dart:io';
import 'dart:ui' as ui;

import 'package:bimobondapp/app/video_templates/composition/media_source.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:flutter/foundation.dart';

/// Still [MediaSource] with a fixed on-timeline hold duration.
///
/// Architecture (same [TemplateCompositionEngine] as video):
/// ```
/// Image file → decode once → GPU/ui.Image texture
///   → timeline hold (N seconds @ recipe fps)
///   → filter / effect / overlay evaluation per output frame
///   → hardware encoder (Media3 image duration / stop-motion)
/// ```
///
/// Does **not** create an intermediate MP4 before composition. Export reuses
/// [imageBytes] / [decodedImage] (decode once); the encoder holds the texture
/// for [holdDuration] and emits frames at the recipe frame rate.
class ImageMediaSource implements MediaSource {
  ImageMediaSource({
    required this.id,
    required this.file,
    required this.holdDuration,
  });

  @override
  final String id;

  @override
  final File file;

  /// On-timeline length of this still (e.g. 2s → 60 frames at 30fps).
  final Duration holdDuration;

  ui.Image? _decoded;
  Uint8List? _bytes;
  bool _prepared = false;

  @override
  String get kind => MediaSourceKinds.image;

  @override
  bool get isPrepared => _prepared;

  /// Decoded GPU-ready frame for preview (Flutter [RawImage] / Texture host).
  ui.Image? get decodedImage => _decoded;

  /// Original file bytes — decode once in [prepare]; export must not re-read
  /// and must not re-decode per output frame.
  Uint8List? get imageBytes => _bytes;

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    try {
      if (!await file.exists()) {
        throw StateError('Image missing: ${file.path}');
      }
      _bytes = await file.readAsBytes();
      // Soft-preview / collage: decode at canvas scale, not full camera res.
      final codec = await ui.instantiateImageCodec(
        _bytes!,
        targetWidth: 540,
      );
      final frame = await codec.getNextFrame();
      _decoded?.dispose();
      _decoded = frame.image;
      _prepared = true;
    } catch (e, st) {
      debugPrint('ImageMediaSource.prepare failed: $e\n$st');
      rethrow;
    }
  }

  /// Reuse an already-decoded still for another slot (clone GPU image).
  static Future<ImageMediaSource> sharePrepared(
    ImageMediaSource other, {
    required String id,
    required Duration holdDuration,
  }) async {
    final src = ImageMediaSource(
      id: id,
      file: other.file,
      holdDuration: holdDuration,
    );
    final image = other._decoded;
    if (image == null || !other._prepared) {
      await src.prepare();
      return src;
    }
    src._bytes = other._bytes;
    src._decoded = image.clone();
    src._prepared = true;
    return src;
  }

  @override
  Future<Duration> getDuration() async => holdDuration;

  /// Stills have no intrinsic timeline — local composition time maps to t=0.
  @override
  Duration mapLocalTime(Duration local) => Duration.zero;

  @override
  Future<void> dispose() async {
    _decoded?.dispose();
    _decoded = null;
    _bytes = null;
    _prepared = false;
  }
}
