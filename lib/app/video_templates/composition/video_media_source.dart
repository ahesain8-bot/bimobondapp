import 'dart:io';

import 'package:bimobondapp/app/video_templates/composition/media_source.dart';
import 'package:bimobondapp/app/video_templates/domain/entities/video_template_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Trimmed / speed-aware video clip source (Phase 4).
class VideoMediaSource implements MediaSource {
  VideoMediaSource({
    required this.id,
    required this.file,
    this.trimStart,
    this.trimEnd,
    this.speed = 1,
    this.volume = 1,
    this.targetDurationSeconds,
  });

  @override
  final String id;

  @override
  final File file;

  final double? trimStart;
  final double? trimEnd;
  final double speed;
  final double volume;
  final double? targetDurationSeconds;

  Duration? _sourceDuration;
  Duration? _effectiveDuration;
  bool _prepared = false;

  @override
  String get kind => MediaSourceKinds.video;

  @override
  bool get isPrepared => _prepared;

  double get _safeSpeed => speed <= 0 ? 1.0 : speed;

  @override
  Future<void> prepare() async {
    if (_prepared) return;
    try {
      if (!await file.exists()) {
        throw StateError('Video missing: ${file.path}');
      }
      final meta = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(file),
      );
      _sourceDuration = meta.duration;
      _effectiveDuration = _computeEffective();
      _prepared = true;
    } catch (e, st) {
      debugPrint('VideoMediaSource.prepare failed: $e\n$st');
      // Soft fallback — still usable with target duration.
      _sourceDuration = Duration(
        milliseconds: ((targetDurationSeconds ?? 3) * 1000).round(),
      );
      _effectiveDuration = _computeEffective();
      _prepared = true;
    }
  }

  Duration _computeEffective() {
    final src = _sourceDuration ?? const Duration(seconds: 3);
    final startSec = (trimStart ?? 0).clamp(0.0, 36000.0);
    double endSec;
    if (trimEnd != null && trimEnd! > startSec) {
      endSec = trimEnd!;
    } else if (targetDurationSeconds != null && targetDurationSeconds! > 0) {
      endSec = startSec + targetDurationSeconds!;
    } else {
      endSec = src.inMilliseconds / 1000.0;
    }
    final raw = (endSec - startSec).clamp(0.05, 36000.0);
    final played = raw / _safeSpeed;
    return Duration(milliseconds: (played * 1000).round());
  }

  /// Inclusive trim window on the source timeline (seconds).
  double get sourceTrimStartSeconds => (trimStart ?? 0).clamp(0.0, 36000.0);

  double get sourceTrimEndSeconds {
    final start = sourceTrimStartSeconds;
    if (trimEnd != null && trimEnd! > start) return trimEnd!;
    if (targetDurationSeconds != null && targetDurationSeconds! > 0) {
      return start + targetDurationSeconds!;
    }
    final srcSec = (_sourceDuration?.inMilliseconds ?? 3000) / 1000.0;
    return srcSec;
  }

  @override
  Future<Duration> getDuration() async {
    if (!_prepared) await prepare();
    return _effectiveDuration ?? _computeEffective();
  }

  @override
  Duration mapLocalTime(Duration local) {
    final startMs = (sourceTrimStartSeconds * 1000).round();
    final localMs = (local.inMilliseconds * _safeSpeed).round();
    return Duration(milliseconds: startMs + localMs);
  }

  @override
  Future<void> dispose() async {
    _prepared = false;
    _sourceDuration = null;
    _effectiveDuration = null;
  }
}
