import 'package:bimobondapp/app/ar_camera/ar_camera_bridge.dart';

/// FaceWarp beauty helpers for live.
///
/// Live starts **raw** (same camera as Add Post image/video). Call [apply]
/// only when the host opts in via Beautify.
class ArLiveBeautyDefaults {
  ArLiveBeautyDefaults._();

  /// Magic smooth slider (0..1) ≈ TikTok Skin Smoothness 40.
  static const double smooth = 0.40;

  /// Magic / beauty whiten (0..1) ≈ TikTok Whiten 10 — keep low.
  static const double whiten = 0.10;

  /// Open midtones ≈ gamma +0.07 (no dedicated gamma slider).
  static const double frontBrightness = 0.07;

  /// Overall lift ≈ exposure +0.12.
  static const double frontExposure = 0.12;

  /// Soft TikTok grade — contrast slightly negative, mild sat/highlight hold.
  static const double frontSaturation = 0.02;
  static const double frontContrast = -0.03;
  static const double frontWhiteBalance = -0.02;
  static const double frontHighlights = -0.05;
  static const double frontShadows = -0.10;

  static const double frontNose = 0.06; // ≈ 6
  static const double frontShape = -0.08; // ≈ face slim 8
  static const double frontEyes = 0.07; // ≈ 7
  static const double frontTooth = 0.08; // ≈ 8
  static const double frontMouth = 0.02; // ≈ 2
  static const double frontBrightenEye = 0.08; // ≈ 8

  /// Raw camera — Magic Off, no retouch / makeup / beauty filter.
  static void clear() {
    ArCameraBridge.setMagicEnabled(false);
    ArCameraBridge.clearBeautyFilter();
    ArCameraBridge.clearRetouchAdjustments();
    ArCameraBridge.clearMakeup();
    ArCameraBridge.setFilter('none');
  }

  /// Turns Magic On and applies the TikTok-open retouch grade.
  static void apply({required bool isFrontCamera}) {
    ArCameraBridge.setMagicEnabled(true, strength: smooth);
    ArCameraBridge.setFilter('none');
    ArCameraBridge.clearMakeup();
    // Explicit whiten=10 so Magic does not lean on a chalky skin lift.
    ArCameraBridge.setBeautyFilter(
      smooth: smooth,
      whiten: whiten,
      brighten: 0,
      blush: 0,
      lipTint: '#E8527A',
      lipStrength: 0,
    );
    if (isFrontCamera) {
      ArCameraBridge.setRetouchAdjustments(
        saturation: frontSaturation,
        brightness: frontBrightness,
        contrast: frontContrast,
        exposure: frontExposure,
        whiteBalance: frontWhiteBalance,
        highlights: frontHighlights,
        shadows: frontShadows,
        nose: frontNose,
        shape: frontShape,
        eyes: frontEyes,
        tooth: frontTooth,
        mouth: frontMouth,
      );
      ArCameraBridge.setMakeup(brightenEye: frontBrightenEye);
    } else {
      ArCameraBridge.setRetouchAdjustments(
        saturation: 0.01,
        brightness: 0.05,
        contrast: -0.02,
        exposure: 0.09,
        whiteBalance: frontWhiteBalance,
        highlights: -0.04,
        shadows: -0.08,
        nose: frontNose * 0.5,
        shape: frontShape * 0.5,
        eyes: frontEyes * 0.5,
        tooth: frontTooth * 0.5,
        mouth: frontMouth * 0.5,
      );
    }
  }

  /// Clear now, then again after GL/CameraX settle (first open often races).
  static Future<void> clearWithRetry() async {
    try {
      await ArCameraBridge.prepareShaderPipeline();
    } catch (_) {}
    clear();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    clear();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    clear();
  }

  /// Apply now, then again after GL/CameraX settle (first open often races).
  static Future<void> applyWithRetry({required bool isFrontCamera}) async {
    try {
      await ArCameraBridge.prepareShaderPipeline();
    } catch (_) {}
    apply(isFrontCamera: isFrontCamera);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    apply(isFrontCamera: isFrontCamera);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    apply(isFrontCamera: isFrontCamera);
  }
}
