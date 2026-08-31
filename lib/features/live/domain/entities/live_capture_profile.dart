import 'package:camera/camera.dart';

/// A 16:9 capture target for the live host pipeline.
///
/// The host broadcasts video, never stills, so every profile below is a true
/// 16:9 video mode. Asking the sensor for its largest mode instead hands back
/// a 4:3 photo format (4032×3024 on recent iPhones); the preview then has to
/// upscale and crop that into the 9:16 viewport, which is what made the feed
/// look soft even while the badge claimed a very high number.
class LiveCaptureProfile {
  const LiveCaptureProfile({
    required this.width,
    required this.height,
    required this.maxFps,
    required this.maxBitrate,
    required this.preset,
    required this.label,
  });

  final int width;
  final int height;
  final int maxFps;

  /// Publish ceiling in bits per second for this profile.
  final int maxBitrate;

  /// Closest `camera` plugin preset for the local preview surface.
  final ResolutionPreset preset;

  /// Short badge text shown in the quality picker (`1080p`, `720p`, …).
  final String label;

  /// 1920×1080 — what TikTok LIVE publishes from a capable handset.
  static const fullHd = LiveCaptureProfile(
    width: 1920,
    height: 1080,
    maxFps: 30,
    maxBitrate: 4500000,
    preset: ResolutionPreset.veryHigh,
    label: '1080p',
  );

  /// 1280×720 — the safe middle tier and our simulcast base layer.
  static const hd = LiveCaptureProfile(
    width: 1280,
    height: 720,
    maxFps: 30,
    maxBitrate: 2500000,
    preset: ResolutionPreset.high,
    label: '720p',
  );

  /// 854×480 — the floor. Nothing below this is ever published (M2 rule).
  static const sd = LiveCaptureProfile(
    width: 854,
    height: 480,
    maxFps: 30,
    maxBitrate: 1200000,
    preset: ResolutionPreset.medium,
    label: '480p',
  );

  /// Highest first. Walked in order until a device actually accepts one,
  /// so a weak handset degrades honestly instead of failing to open.
  static const List<LiveCaptureProfile> ladder = [fullHd, hd, sd];

  /// Stable default for live publishing.
  ///
  /// The host already *captures* at 1080x1920 — that is what CameraX binds the
  /// preview to (`PREVIEW_TARGET_WIDTH/HEIGHT` in `ArCameraController`) and
  /// what the AR renderer draws. Publishing at 720p threw that away by
  /// downscaling a 1080p source, which is what made the broadcast look soft
  /// next to TikTok.
  ///
  /// The old default was 720p because some Android Camera2 implementations
  /// report 1080p as supported and then fail asynchronously while configuring
  /// the capture session, leaving a valid-looking track that produces no
  /// frames. That risk is real but it is now covered rather than avoided:
  /// `_waitForOutboundVideo` refuses a profile that yields no frames, and the
  /// publish walks [ladder] down to 720p and 480p — on the AR path too, where
  /// resizing the renderer's output surface costs nothing like reopening a
  /// lens does. A handset that cannot hold 1080p still goes live, one tier
  /// lower, instead of the whole ladder starting one tier low for everyone.
  static const LiveCaptureProfile preferred = fullHd;

  /// The profiles at or below [this], highest first.
  ///
  /// Used to build the simulcast ladder so the SFU always has a lower layer
  /// to hand a viewer on a poor connection.
  List<LiveCaptureProfile> get fallbacks =>
      ladder.skipWhile((profile) => profile != this).toList();

  String get dimensions => '$width × $height';

  @override
  bool operator ==(Object other) =>
      other is LiveCaptureProfile &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}
