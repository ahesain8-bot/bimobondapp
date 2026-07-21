import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tone/color adjustments via native OpenCV (Android).
///
/// All values are -1…1 → native -100…100 (0 = original).
class MediaSkinSmooth {
  MediaSkinSmooth._();

  static Future<File?> apply({
    required File input,
    double saturation = 0,
    double brightness = 0,
    double contrast = 0,
    double exposure = 0,
    double whiteBalance = 0,
    double highlights = 0,
    double shadows = 0,
    double nose = 0,
    int? maxEdge,
  }) async {
    final satT = saturation.clamp(-1.0, 1.0);
    final brightT = brightness.clamp(-1.0, 1.0);
    final contrastT = contrast.clamp(-1.0, 1.0);
    final exposureT = exposure.clamp(-1.0, 1.0);
    final wbT = whiteBalance.clamp(-1.0, 1.0);
    final highlightsT = highlights.clamp(-1.0, 1.0);
    final shadowsT = shadows.clamp(-1.0, 1.0);
    final noseT = nose.clamp(-1.0, 1.0);

    final hasEdit = satT.abs() > 0.01 ||
        brightT.abs() > 0.01 ||
        contrastT.abs() > 0.01 ||
        exposureT.abs() > 0.01 ||
        wbT.abs() > 0.01 ||
        highlightsT.abs() > 0.01 ||
        shadowsT.abs() > 0.01 ||
        noseT.abs() > 0.01;
    if (!hasEdit) return null;
    if (!await input.exists()) return null;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    int lvl(double t) => (t * 100).round().clamp(-100, 100);

    try {
      final outPath = await ArCameraBridge.applyBeauty(
        path: input.path,
        saturationLevel: lvl(satT),
        brightnessLevel: lvl(brightT),
        contrastLevel: lvl(contrastT),
        exposureLevel: lvl(exposureT),
        whiteBalanceLevel: lvl(wbT),
        highlightsLevel: lvl(highlightsT),
        shadowsLevel: lvl(shadowsT),
        noseLevel: lvl(noseT),
        maxEdge: maxEdge,
      );
      if (outPath == null || outPath.isEmpty) return null;
      final out = File(outPath);
      if (!await out.exists()) return null;
      return out;
    } on PlatformException catch (e, st) {
      debugPrint('MediaSkinSmooth.applyBeauty failed: ${e.code} ${e.message}\n$st');
      return null;
    } catch (e, st) {
      debugPrint('MediaSkinSmooth.apply failed: $e\n$st');
      return null;
    }
  }
}
