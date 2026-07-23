import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:bimobondapp/app/home/presentation/widgets/add_post/camera/camera_effect_asset_loader.dart';
import 'package:flutter/material.dart';

class CameraToolIcons {
  CameraToolIcons._();

  /// Vertical gap between side-rail tool rows (camera + media editor).
  static const double railRowSpacing = 6.0;

  static const labelStyle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.1,
    shadows: [
      Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
    ],
  );

  /// Soft drop-shadow for rail glyphs (Icon / SVG / custom paint).
  static const iconShadows = <Shadow>[
    Shadow(
      color: Color(0x59000000),
      blurRadius: 5,
      offset: Offset(0, 1),
    ),
  ];

  static Widget withSoftShadow(Widget child) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          child: Transform.translate(
            offset: const Offset(0, 1),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
              child: Opacity(
                opacity: 0.45,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.black,
                    BlendMode.srcIn,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  static BoxDecoration circleDecoration({bool active = false}) {
    return BoxDecoration(
      color: active
          ? Colors.white.withValues(alpha: 0.92)
          : Colors.black.withValues(alpha: 0.28),
      shape: BoxShape.circle,
      border: Border.all(
        color: active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration squareDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration galleryThumbDecoration() {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.95),
        width: 1.5,
      ),
    );
  }
}

/// Soft vertical fade behind an expanded side rail (TikTok-style).
/// Diffused / rounded edges — no hard rectangular outline.
class CameraRailExpandedBackdrop extends StatelessWidget {
  const CameraRailExpandedBackdrop({
    super.key,
    required this.expanded,
    required this.iconOnStartEdge,
    this.width = 128,
  });

  final bool expanded;
  final bool iconOnStartEdge;
  final double width;

  @override
  Widget build(BuildContext context) {
    final openRadius = const Radius.circular(36);
    final borderRadius = BorderRadius.only(
      topLeft: iconOnStartEdge ? Radius.zero : openRadius,
      bottomLeft: iconOnStartEdge ? Radius.zero : openRadius,
      topRight: iconOnStartEdge ? openRadius : Radius.zero,
      bottomRight: iconOnStartEdge ? openRadius : Radius.zero,
    );

    return Positioned(
      top: -28,
      bottom: -24,
      left: iconOnStartEdge ? -18 : null,
      right: iconOnStartEdge ? null : -18,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          opacity: expanded ? 1 : 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            width: expanded ? width : 56,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: iconOnStartEdge
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    end: iconOnStartEdge
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.34),
                      Colors.black.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.28, 0.62, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CameraRailTool extends StatelessWidget {
  const CameraRailTool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 42.0 : 48.0;
    final iconSize = compact ? 20.0 : 24.0;
    final bottomPad = compact ? 8.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: CameraToolIcons.circleDecoration(active: active),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: active ? Colors.black : Colors.white,
                    size: iconSize,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: compact ? 50 : 56,
              child: Text(
                label,
                style: CameraToolIcons.labelStyle.copyWith(
                  fontSize: compact ? 10 : 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CameraRailToolRow extends StatelessWidget {
  const CameraRailToolRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.showActiveBadge,
    this.badge,
    this.iconOnStartEdge = true,
    this.customIcon,
    this.showLabel = false,
    this.rowSpacing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool? showActiveBadge;
  final String? badge;
  final bool iconOnStartEdge;
  final Widget? customIcon;
  final bool showLabel;
  final double? rowSpacing;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: customIcon != null
                ? CameraToolIcons.withSoftShadow(customIcon!)
                : Icon(
                    icon,
                    color: Colors.white,
                    size: 30,
                    shadows: CameraToolIcons.iconShadows,
                  ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: iconOnStartEdge ? -2 : null,
            left: iconOnStartEdge ? null : -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (showActiveBadge ?? active)
          Positioned(
            right: iconOnStartEdge ? -3 : null,
            left: iconOnStartEdge ? null : -3,
            top: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFFFE2C55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 9,
              ),
            ),
          ),
      ],
    );

    final labelWidget = Text(
      label,
      style: CameraToolIcons.labelStyle.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: iconOnStartEdge ? TextAlign.left : TextAlign.right,
    );

    final labelSlot = ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        alignment: iconOnStartEdge ? Alignment.centerLeft : Alignment.centerRight,
        widthFactor: showLabel ? 1.0 : 0.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
          opacity: showLabel ? 1 : 0,
          child: Padding(
            padding: EdgeInsets.only(
              left: iconOnStartEdge ? 8 : 0,
              right: iconOnStartEdge ? 0 : 8,
            ),
            child: labelWidget,
          ),
        ),
      ),
    );

    final rowChildren = <Widget>[
      if (!iconOnStartEdge) labelSlot,
      iconWidget,
      if (iconOnStartEdge) labelSlot,
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: rowSpacing ?? CameraToolIcons.railRowSpacing,
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          alignment:
              iconOnStartEdge ? Alignment.centerLeft : Alignment.centerRight,
          child: Row(
            mainAxisAlignment: iconOnStartEdge
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: rowChildren,
          ),
        ),
      ),
    );
  }
}

class CameraBottomTool extends StatelessWidget {
  const CameraBottomTool({
    super.key,
    required this.onTap,
    this.icon,
    this.label,
    this.child,
    this.size = 52,
  });

  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final Widget? child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: CameraToolIcons.circleDecoration(),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: child ??
                  Icon(icon, color: Colors.white, size: size * 0.46),
            ),
            if (label != null) ...[
              const SizedBox(height: 5),
              Text(
                label!,
                style: CameraToolIcons.labelStyle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CameraGalleryTool extends StatelessWidget {
  const CameraGalleryTool({
    super.key,
    required this.onTap,
    required this.label,
    this.icon = Icons.photo_library_rounded,
    this.compact = false,
  });

  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 40.0 : 48.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: compact
          ? Container(
              width: size,
              height: size,
              decoration: CameraToolIcons.galleryThumbDecoration(),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 20),
            )
          : SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: CameraToolIcons.squareDecoration(),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: CameraToolIcons.labelStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
    );
  }
}

class CameraEffectsTool extends StatelessWidget {
  const CameraEffectsTool({
    super.key,
    required this.onTap,
    required this.label,
    this.emoji,
    this.assetUrl,
    this.previewColor,
    this.hasSelection = false,
  });

  final VoidCallback onTap;
  final String label;
  final String? emoji;
  final String? assetUrl;
  final Color? previewColor;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasSelection && previewColor != null
                    ? RadialGradient(
                        colors: [
                          previewColor!.withValues(alpha: 0.9),
                          previewColor!.withValues(alpha: 0.45),
                        ],
                      )
                    : null,
                color: hasSelection ? null : Colors.black.withValues(alpha: 0.28),
                border: Border.all(
                  color: hasSelection
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18),
                  width: hasSelection ? 2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _buildPreview(),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: CameraToolIcons.labelStyle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (hasSelection && (assetUrl != null || emoji != null)) {
      return CameraEffectAssetLoader.preview(
        raw: assetUrl,
        emojiFallback: emoji,
        size: 52,
      );
    }
    return const Icon(Icons.auto_awesome, color: Colors.white, size: 24);
  }
}

class TikTokSideIcons {
  TikTokSideIcons._();

  static Widget flip({double size = 30}) => _Glyph(
        size: size,
        painter: _FlipPainter(),
      );

  static Widget flash({required bool enabled, double size = 30}) => _Glyph(
        size: size,
        painter: _FlashPainter(enabled: enabled),
      );

  static Widget timer({double size = 30}) => _Glyph(
        size: size,
        painter: _TimerPainter(),
      );

  static Widget layout({double size = 30}) => _Glyph(
        size: size,
        painter: _LayoutPainter(),
      );

  static Widget retouch({double size = 30}) => _Glyph(
        size: size,
        painter: _RetouchPainter(),
      );

  static Widget filters({double size = 30}) => _Glyph(
        size: size,
        painter: _FiltersPainter(),
      );

  static Widget speed({required String label, double size = 32}) => _Glyph(
        size: size,
        painter: _SpeedPainter(label: label),
      );
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.size, required this.painter});

  final double size;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter),
    );
  }
}

Paint _stroke(double size, {double factor = 0.085}) => Paint()
  ..color = Colors.white
  ..style = PaintingStyle.stroke
  ..strokeWidth = size * factor
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _FlipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(size.width, factor: 0.09);
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.36;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -2.35,
      2.55,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0.8,
      2.55,
      false,
      paint,
    );

    final fill = Paint()..color = Colors.white;
    // Top-right arrow head
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + r * 0.15, c.dy - r * 1.05)
        ..lineTo(c.dx + r * 1.05, c.dy - r * 0.55)
        ..lineTo(c.dx + r * 0.35, c.dy - r * 0.35)
        ..close(),
      fill,
    );
    // Bottom-left arrow head
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - r * 0.15, c.dy + r * 1.05)
        ..lineTo(c.dx - r * 1.05, c.dy + r * 0.55)
        ..lineTo(c.dx - r * 0.35, c.dy + r * 0.35)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlashPainter extends CustomPainter {
  _FlashPainter({required this.enabled});

  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bolt = Path()
      ..moveTo(w * 0.58, h * 0.06)
      ..lineTo(w * 0.30, h * 0.50)
      ..lineTo(w * 0.48, h * 0.50)
      ..lineTo(w * 0.40, h * 0.94)
      ..lineTo(w * 0.72, h * 0.44)
      ..lineTo(w * 0.54, h * 0.44)
      ..close();
    canvas.drawPath(bolt, Paint()..color = Colors.white);

    if (!enabled) {
      // TikTok-style diagonal slash through the bolt.
      final slash = Paint()
        ..color = Colors.white
        ..strokeWidth = w * 0.11
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(w * 0.18, h * 0.18),
        Offset(w * 0.82, h * 0.82),
        slash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlashPainter oldDelegate) =>
      oldDelegate.enabled != enabled;
}

class _TimerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(size.width, factor: 0.09);
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h * 0.56);
    final r = w * 0.34;

    // Stopwatch body
    canvas.drawCircle(c, r, paint);
    // Top crown
    canvas.drawLine(
      Offset(w * 0.42, h * 0.14),
      Offset(w * 0.58, h * 0.14),
      paint,
    );
    canvas.drawLine(
      Offset(w / 2, h * 0.14),
      Offset(w / 2, c.dy - r),
      paint,
    );
    // Side button
    canvas.drawLine(
      Offset(c.dx + r * 0.72, c.dy - r * 0.72),
      Offset(c.dx + r * 1.05, c.dy - r * 1.05),
      paint,
    );
    // Hands
    canvas.drawLine(c, Offset(c.dx, c.dy - r * 0.55), paint);
    canvas.drawLine(c, Offset(c.dx + r * 0.45, c.dy + r * 0.15), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LayoutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(size.width, factor: 0.09);
    final inset = size.width * 0.12;
    final gap = size.width * 0.06;
    final box = size.width - inset * 2;
    final cell = (box - gap) / 2;

    RRect cellRect(double dx, double dy) => RRect.fromRectAndRadius(
          Rect.fromLTWH(inset + dx, inset + dy, cell, cell),
          Radius.circular(size.width * 0.06),
        );

    canvas.drawRRect(cellRect(0, 0), paint);
    canvas.drawRRect(cellRect(cell + gap, 0), paint);
    canvas.drawRRect(cellRect(0, cell + gap), paint);
    canvas.drawRRect(cellRect(cell + gap, cell + gap), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RetouchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(size.width, factor: 0.085);
    final w = size.width;
    final h = size.height;

    // Head
    canvas.drawCircle(Offset(w * 0.42, h * 0.32), w * 0.18, paint);
    // Shoulders / bust
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.42, h * 0.92),
        width: w * 0.62,
        height: h * 0.55,
      ),
      3.6,
      2.5,
      false,
      paint,
    );
    // Sparkle (4-point star)
    final sx = w * 0.78;
    final sy = h * 0.28;
    final arm = w * 0.14;
    canvas.drawLine(Offset(sx, sy - arm), Offset(sx, sy + arm), paint);
    canvas.drawLine(Offset(sx - arm, sy), Offset(sx + arm, sy), paint);
    final d = arm * 0.55;
    canvas.drawLine(Offset(sx - d, sy - d), Offset(sx + d, sy + d), paint);
    canvas.drawLine(Offset(sx + d, sy - d), Offset(sx - d, sy + d), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FiltersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(size.width, factor: 0.085);
    final r = size.width * 0.24;
    final c1 = Offset(size.width * 0.34, size.height * 0.38);
    final c2 = Offset(size.width * 0.66, size.height * 0.38);
    final c3 = Offset(size.width * 0.50, size.height * 0.66);
    canvas.drawCircle(c1, r, paint);
    canvas.drawCircle(c2, r, paint);
    canvas.drawCircle(c3, r, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter({required this.label});

  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(size.width, factor: 0.085);
    final c = Offset(size.width / 2, size.height * 0.58);
    final r = size.width * 0.38;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      3.55,
      2.6,
      false,
      paint,
    );
    canvas.drawLine(
      c,
      Offset(c.dx + r * 0.5, c.dy - r * 0.55),
      paint,
    );
    // Tick marks
    for (final a in [3.7, 4.2, 4.7, 5.2, 5.7]) {
      final inner = Offset(
        c.dx + (r - size.width * 0.08) * math.cos(a),
        c.dy + (r - size.width * 0.08) * math.sin(a),
      );
      final outer = Offset(
        c.dx + r * math.cos(a),
        c.dy + r * math.sin(a),
      );
      canvas.drawLine(inner, outer, paint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.26,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(c.dx - tp.width / 2, c.dy + r * 0.02),
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter oldDelegate) =>
      oldDelegate.label != label;
}
