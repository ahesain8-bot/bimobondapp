import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

/// Guards FFmpeg usage when the native plugin is missing or unsupported.
class FfmpegKitSupport {
  FfmpegKitSupport._();

  static bool? _cachedAvailable;

  static Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    final cached = _cachedAvailable;
    if (cached != null) return cached;

    try {
      final session = await FFmpegKit.execute('-version').timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw StateError('FFmpegKit probe timed out'),
      );
      final code = await session.getReturnCode();
      _cachedAvailable = ReturnCode.isSuccess(code);
    } catch (e, st) {
      debugPrint('FFmpegKit unavailable: $e\n$st');
      _cachedAvailable = false;
    }
    return _cachedAvailable!;
  }

  static void markUnavailable() => _cachedAvailable = false;
}
