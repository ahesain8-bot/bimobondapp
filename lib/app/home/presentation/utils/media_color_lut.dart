import 'dart:io';

import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';
import 'package:bimobondapp/app/ar_camera/ar_color_filter_catalog_model.dart';
import 'package:bimobondapp/app/ar_camera/ar_filter_catalog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bakes a color grade (Life / Portrait / Retro / Film …) onto a still image
/// via the native PNG-LUT engine — the exact same lookup the live camera uses.
///
/// Beauty filters (Soft Glow) use [SoftGlowBaker] on native instead of LUT.
class MediaColorLut {
  MediaColorLut._();

  static Map<String, dynamic>? beautyParamsForId(String filterId) {
    final model = ArFilterCatalog.colorFilterModelForId(filterId);
    if (model == null || !model.isBeauty) return null;
    final p = model.params ?? ArBeautyFilterParams.defaults;
    return {
      'smooth': p.smooth,
      'whiten': p.whiten,
      'brighten': p.brighten,
      'blush': p.blush,
      'lipTint': p.lipTint,
      'lipStrength': p.lipStrength,
    };
  }

  static Future<File?> apply({
    required File input,
    required String filterId,
    double intensity = 1.0,
    int? maxEdge,
  }) async {
    if (filterId.isEmpty || filterId == 'none') return null;
    if (intensity <= 0.001) return null;
    if (!await input.exists()) return null;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final beauty = beautyParamsForId(filterId);
      final outPath = await ArCameraBridge.applyColorLut(
        path: input.path,
        filter: filterId,
        intensity: intensity.clamp(0.0, 1.0),
        maxEdge: maxEdge,
        lutUrl: beauty == null ? ArFilterCatalog.pngLutUrlForId(filterId) : null,
        beautyParams: beauty,
      );
      if (outPath == null || outPath.isEmpty) return null;
      final out = File(outPath);
      if (!await out.exists()) return null;
      return out;
    } on PlatformException catch (e, st) {
      debugPrint('MediaColorLut.apply failed: ${e.code} ${e.message}\n$st');
      return null;
    } catch (e, st) {
      debugPrint('MediaColorLut.apply failed: $e\n$st');
      return null;
    }
  }
}
