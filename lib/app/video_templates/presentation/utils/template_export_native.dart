import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android MethodChannel for shared GPU template composer + export.
///
/// Channel: `com.dubai.bimobondapp/template_export`
class TemplateExportNative {
  TemplateExportNative._();

  static const _channel = MethodChannel(
    'com.dubai.bimobondapp/template_export',
  );

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<File?> composeTimeline({
    required int width,
    required int height,
    required int fps,
    required int bitrate,
    required List<TemplateExportNativeClip> clips,
    TemplateExportNativeAudio? audio,
    List<double>? colorMatrix,
    List<TemplateExportNativeOverlay>? overlays,
  }) async {
    if (!supported || clips.isEmpty) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'composeTimeline',
        _timelineArgs(
          width: width,
          height: height,
          fps: fps,
          bitrate: bitrate,
          clips: clips,
          audio: audio,
          colorMatrix: colorMatrix,
          overlays: overlays,
        ),
      );
      return _fileFromResult(result);
    } on PlatformException catch (e, st) {
      debugPrint('TemplateExportNative.composeTimeline: ${e.message}\n$st');
      return null;
    } catch (e, st) {
      debugPrint('TemplateExportNative.composeTimeline: $e\n$st');
      return null;
    }
  }

  /// Opens a GPU preview session. Returns texture id + size.
  static Future<TemplateGpuPreviewSession?> openPreview({
    required int width,
    required int height,
    required int fps,
    required int bitrate,
    required List<TemplateExportNativeClip> clips,
    TemplateExportNativeAudio? audio,
    List<double>? colorMatrix,
    List<TemplateExportNativeOverlay>? overlays,
  }) async {
    if (!supported || clips.isEmpty) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'openPreview',
        _timelineArgs(
          width: width,
          height: height,
          fps: fps,
          bitrate: bitrate,
          clips: clips,
          audio: audio,
          colorMatrix: colorMatrix,
          overlays: overlays,
        ),
      );
      final id = result?['textureId'];
      final textureId = id is int ? id : (id is num ? id.toInt() : null);
      if (textureId == null) return null;
      return TemplateGpuPreviewSession(
        textureId: textureId,
        width: (result?['width'] as num?)?.toInt() ?? width,
        height: (result?['height'] as num?)?.toInt() ?? height,
        durationMs: (result?['durationMs'] as num?)?.toInt() ?? 0,
      );
    } on PlatformException catch (e, st) {
      debugPrint('TemplateExportNative.openPreview: ${e.message}\n$st');
      return null;
    } catch (e, st) {
      debugPrint('TemplateExportNative.openPreview: $e\n$st');
      return null;
    }
  }

  static Future<void> setRecipe({
    required int width,
    required int height,
    required int fps,
    required int bitrate,
    required List<TemplateExportNativeClip> clips,
    TemplateExportNativeAudio? audio,
    List<double>? colorMatrix,
    List<TemplateExportNativeOverlay>? overlays,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>(
        'setRecipe',
        _timelineArgs(
          width: width,
          height: height,
          fps: fps,
          bitrate: bitrate,
          clips: clips,
          audio: audio,
          colorMatrix: colorMatrix,
          overlays: overlays,
        ),
      );
    } catch (e, st) {
      debugPrint('TemplateExportNative.setRecipe: $e\n$st');
    }
  }

  static Future<void> seek(int ms) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('seek', <String, Object?>{'ms': ms});
    } catch (_) {}
  }

  static Future<void> play() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('play');
    } catch (_) {}
  }

  static Future<void> pause() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('pause');
    } catch (_) {}
  }

  /// Export from the open preview session (same draw path).
  static Future<File?> exportSession({String quality = 'draft'}) async {
    if (!supported) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'exportSession',
        <String, Object?>{'quality': quality},
      );
      return _fileFromResult(result);
    } on PlatformException catch (e, st) {
      debugPrint('TemplateExportNative.exportSession: ${e.message}\n$st');
      return null;
    } catch (e, st) {
      debugPrint('TemplateExportNative.exportSession: $e\n$st');
      return null;
    }
  }

  static Future<void> disposePreview() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('disposePreview');
    } catch (_) {}
  }

  static Map<String, Object?> _timelineArgs({
    required int width,
    required int height,
    required int fps,
    required int bitrate,
    required List<TemplateExportNativeClip> clips,
    TemplateExportNativeAudio? audio,
    List<double>? colorMatrix,
    List<TemplateExportNativeOverlay>? overlays,
  }) {
    return <String, Object?>{
      'width': width,
      'height': height,
      'fps': fps,
      'bitrate': bitrate,
      'clips': clips.map((c) => c.toMap()).toList(growable: false),
      if (audio != null) 'audio': audio.toMap(),
      if (colorMatrix != null && colorMatrix.length >= 20) 'colorMatrix': colorMatrix,
      if (overlays != null && overlays.isNotEmpty)
        'overlays': overlays.map((o) => o.toMap()).toList(growable: false),
    };
  }

  static Future<File?> _fileFromResult(Map<Object?, Object?>? result) async {
    final path = result?['path']?.toString().trim();
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) return null;
    return file;
  }
}

class TemplateGpuPreviewSession {
  const TemplateGpuPreviewSession({
    required this.textureId,
    required this.width,
    required this.height,
    required this.durationMs,
  });

  final int textureId;
  final int width;
  final int height;
  final int durationMs;
}

class TemplateExportNativeClip {
  const TemplateExportNativeClip({
    required this.type,
    required this.path,
    required this.durationMs,
    this.trimStartMs,
    this.trimEndMs,
    this.volume = 1,
  });

  final String type;
  final String path;
  final int durationMs;
  final int? trimStartMs;
  final int? trimEndMs;
  final double volume;

  Map<String, Object?> toMap() => <String, Object?>{
        'type': type,
        'path': path,
        'durationMs': durationMs,
        if (trimStartMs != null) 'trimStartMs': trimStartMs,
        if (trimEndMs != null) 'trimEndMs': trimEndMs,
        'volume': volume,
      };
}

class TemplateExportNativeAudio {
  const TemplateExportNativeAudio({
    required this.path,
    this.startMs = 0,
    this.endMs,
    this.volume = 1,
  });

  final String path;
  final int startMs;
  final int? endMs;
  final double volume;

  Map<String, Object?> toMap() => <String, Object?>{
        'path': path,
        'startMs': startMs,
        if (endMs != null) 'endMs': endMs,
        'volume': volume,
      };
}

class TemplateExportNativeOverlay {
  const TemplateExportNativeOverlay({
    required this.path,
    this.startMs = 0,
    this.endMs,
    this.opacity = 1,
  });

  final String path;
  final int startMs;
  final int? endMs;
  final double opacity;

  Map<String, Object?> toMap() => <String, Object?>{
        'path': path,
        'startMs': startMs,
        if (endMs != null) 'endMs': endMs,
        'opacity': opacity,
      };
}
