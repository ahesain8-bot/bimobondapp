import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CameraRatioLetterbox {
  CameraRatioLetterbox._();

  static double topHeight(double topPadding) => topPadding + 56.0;

  static double tikTokTopChromeHeight(
    double topPadding, {
    bool photoMode = false,
  }) =>
      topPadding + (photoMode ? 96.0 : 28.0);

  static double bottomHeight({
    required bool useNativeAr,
    required bool filtersPanelOpen,
  }) {
    if (filtersPanelOpen) return 220.0;
    return useNativeAr ? 268.0 : 210.0;
  }

  static double tikTokBottomChromeHeight(
    double bottomPadding, {
    bool photoMode = false,
  }) =>
      bottomPadding + (photoMode ? 215.0 : 108.0);

  static const double tikTokPreviewRadius = 22.0;
  static const Duration chromeAnimDuration = Duration(milliseconds: 420);
  static const Curve chromeAnimCurve = Curves.easeInOutCubic;

  static Size previewSize({
    required Size screenSize,
    required double topInset,
    required bool letterboxed,
    required bool useNativeAr,
    required bool filtersPanelOpen,
  }) {
    if (!letterboxed) return screenSize;
    final top = topHeight(topInset);
    final bottom = bottomHeight(
      useNativeAr: useNativeAr,
      filtersPanelOpen: filtersPanelOpen,
    );
    final midH =
        (screenSize.height - top - bottom).clamp(1.0, screenSize.height);
    return Size(screenSize.width, midH);
  }

  /// TikTok preview chrome insets — matches camera photo or video mode.
  static ({double top, double bottom}) tikTokChromeHeights(
    BuildContext context, {
    required bool photoMode,
  }) {
    final padding = MediaQuery.paddingOf(context);
    return (
      top: tikTokTopChromeHeight(padding.top, photoMode: photoMode),
      bottom: tikTokBottomChromeHeight(padding.bottom, photoMode: photoMode),
    );
  }

  /// Side rail / top bar row — same offset as [CameraStudioOverlay].
  static double controlsTopInset(BuildContext context) =>
      tikTokTopChromeHeight(MediaQuery.paddingOf(context).top) + 16.0;
}

/// Clips preview media to the rounded rect between top/bottom chrome bars.
class TikTokPhotoPreviewClip extends StatelessWidget {
  const TikTokPhotoPreviewClip({
    super.key,
    required this.topHeight,
    required this.bottomHeight,
    required this.child,
  });

  final double topHeight;
  final double bottomHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TikTokPreviewClipper(top: topHeight, bottom: bottomHeight),
      child: child,
    );
  }
}

/// Black bars above and below the TikTok-style preview window.
class TikTokChromeBarsOverlay extends StatelessWidget {
  const TikTokChromeBarsOverlay({
    super.key,
    required this.topHeight,
    required this.bottomHeight,
    this.animated = true,
  });

  final double topHeight;
  final double bottomHeight;
  final bool animated;

  static const _bar = ColoredBox(color: Color(0xFF000000));

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPositioned(
            duration: CameraRatioLetterbox.chromeAnimDuration,
            curve: CameraRatioLetterbox.chromeAnimCurve,
            left: 0,
            right: 0,
            top: 0,
            height: topHeight,
            child: const IgnorePointer(child: _bar),
          ),
          AnimatedPositioned(
            duration: CameraRatioLetterbox.chromeAnimDuration,
            curve: CameraRatioLetterbox.chromeAnimCurve,
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomHeight,
            child: const IgnorePointer(child: _bar),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: topHeight,
          child: const IgnorePointer(child: _bar),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: bottomHeight,
          child: const IgnorePointer(child: _bar),
        ),
      ],
    );
  }
}

class TikTokPreviewClipper extends CustomClipper<Path> {
  TikTokPreviewClipper({
    required this.top,
    required this.bottom,
    this.radius = CameraRatioLetterbox.tikTokPreviewRadius,
  });

  final double top;
  final double bottom;
  final double radius;

  @override
  Path getClip(Size size) {
    final midBottom = (size.height - bottom).clamp(top + 1.0, size.height);
    final rect = Rect.fromLTRB(0, top, size.width, midBottom);
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  @override
  bool shouldReclip(covariant TikTokPreviewClipper oldClipper) =>
      oldClipper.top != top ||
      oldClipper.bottom != bottom ||
      oldClipper.radius != radius;
}

/// Clips to an absolute [rect] in the child's coordinate space.
class RectPreviewClipper extends CustomClipper<Path> {
  RectPreviewClipper(this.rect);

  final Rect rect;

  @override
  Path getClip(Size size) => Path()..addRect(rect);

  @override
  bool shouldReclip(covariant RectPreviewClipper oldClipper) =>
      oldClipper.rect != rect;
}

class CameraCaptureUtils {
  CameraCaptureUtils._();

  /// Match native AR JPEG quality — never down-quality for "speed".
  static const int jpegQuality = 95;

  /// True when pixels already match upright display (no bake needed).
  static bool isAlreadyUprightJpeg(Uint8List bytes) {
    final exif = img.decodeJpgExif(bytes);
    if (exif == null || !exif.imageIfd.hasOrientation) return true;
    final o = exif.imageIfd.orientation;
    return o == null || o == 1;
  }

  /// Bakes EXIF orientation into pixels so preview matches the saved file.
  ///
  /// Fast path: EXIF-only check — if already upright, returns [file] unchanged
  /// (no decode/re-encode → original quality preserved).
  /// Slow path: bake + JPEG encode at [jpegQuality] on a background isolate.
  static Future<File> normalizeCapturedImage(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return file;
    if (isAlreadyUprightJpeg(bytes)) return file;

    final encoded = await compute(_normalizeJpegIsolate, bytes);
    if (encoded == null) return file;

    final tempDir = await getTemporaryDirectory();
    final out = File(
      '${tempDir.path}/norm_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(encoded, flush: false);
    return out;
  }

  static Uint8List? normalizeImageBytes(Uint8List bytes) {
    if (isAlreadyUprightJpeg(bytes)) return null;
    return _normalizeJpegIsolate(bytes);
  }

  /// Decodes image bytes with EXIF orientation applied — for compositors.
  static img.Image? decodeNormalized(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.bakeOrientation(decoded);
  }

  static Uint8List encodeJpg(img.Image image, {int quality = jpegQuality}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Crops the frame to what FILL_CENTER shows in [viewportSize] (WYSIWYG).
  static Future<File> cropToFillCenterViewport({
    required File file,
    required Size viewportSize,
  }) async {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return file;

    final bytes = await file.readAsBytes();
    final cropped = await compute(
      _cropIsolate,
      _CropArgs(
        bytes: bytes,
        viewW: viewportSize.width,
        viewH: viewportSize.height,
      ),
    );
    if (cropped == null) return file;

    final tempDir = await getTemporaryDirectory();
    final out = File(
      '${tempDir.path}/ratio_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(cropped, flush: false);
    return out;
  }
}

/// Isolate entry: bake orientation + encode at high quality.
Uint8List? _normalizeJpegIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final image = img.bakeOrientation(decoded);
  return Uint8List.fromList(
    img.encodeJpg(image, quality: CameraCaptureUtils.jpegQuality),
  );
}

class _CropArgs {
  const _CropArgs({
    required this.bytes,
    required this.viewW,
    required this.viewH,
  });

  final Uint8List bytes;
  final double viewW;
  final double viewH;
}

Uint8List? _cropIsolate(_CropArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) return null;
  final image = img.bakeOrientation(decoded);

  final imgW = image.width.toDouble();
  final imgH = image.height.toDouble();
  final viewW = args.viewW;
  final viewH = args.viewH;

  final scale = math.max(viewW / imgW, viewH / imgH);
  final displayW = imgW * scale;
  final displayH = imgH * scale;
  final offsetX = (viewW - displayW) / 2.0;
  final offsetY = (viewH - displayH) / 2.0;

  var left = ((0 - offsetX) / scale).floor();
  var top = ((0 - offsetY) / scale).floor();
  var right = ((viewW - offsetX) / scale).ceil();
  var bottom = ((viewH - offsetY) / scale).ceil();

  left = left.clamp(0, image.width - 1);
  top = top.clamp(0, image.height - 1);
  right = right.clamp(left + 1, image.width);
  bottom = bottom.clamp(top + 1, image.height);

  final cropped = img.copyCrop(
    image,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  return Uint8List.fromList(
    img.encodeJpg(cropped, quality: CameraCaptureUtils.jpegQuality),
  );
}
