import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Frosted liquid-glass container for inputs, chips, and controls on glass UI.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 20,
    this.backgroundColor = const Color(0x1AFFFFFF),
    this.borderColor = const Color(0x26FFFFFF),
    this.padding,
    super.key,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color backgroundColor;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Shimmer colors for glass sheet loading placeholders.
abstract final class LiquidGlassSkeletonStyle {
  LiquidGlassSkeletonStyle._();

  /// Reposts and similar glass lists.
  static Color get fill => Colors.white.withValues(alpha: 0.12);
  static Color get base => Colors.white.withValues(alpha: 0.08);
  static Color get highlight => Colors.white.withValues(alpha: 0.22);

  /// Brighter placeholders for the comments sheet.
  static Color get lightFill => Colors.white.withValues(alpha: 0.2);
  static Color get lightBase => Colors.white.withValues(alpha: 0.14);
  static Color get lightHighlight => Colors.white.withValues(alpha: 0.32);
}

enum LiquidGlassSkeletonTone { standard, light }

/// Shimmer placeholder for liquid-glass surfaces (sheets, lists on glass).
class LiquidGlassSkeletonBox extends StatelessWidget {
  const LiquidGlassSkeletonBox({
    this.height,
    this.width,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.tone = LiquidGlassSkeletonTone.standard,
    super.key,
  });

  const LiquidGlassSkeletonBox.circular({
    required double size,
    this.tone = LiquidGlassSkeletonTone.standard,
    super.key,
  }) : height = size,
       width = size,
       borderRadius = size / 2,
       shape = BoxShape.circle;

  final double? height;
  final double? width;
  final double borderRadius;
  final BoxShape shape;
  final LiquidGlassSkeletonTone tone;

  Color get _fill => tone == LiquidGlassSkeletonTone.light
      ? LiquidGlassSkeletonStyle.lightFill
      : LiquidGlassSkeletonStyle.fill;

  Color get _base => tone == LiquidGlassSkeletonTone.light
      ? LiquidGlassSkeletonStyle.lightBase
      : LiquidGlassSkeletonStyle.base;

  Color get _highlight => tone == LiquidGlassSkeletonTone.light
      ? LiquidGlassSkeletonStyle.lightHighlight
      : LiquidGlassSkeletonStyle.highlight;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _base,
      highlightColor: _highlight,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: _fill,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle
              ? BorderRadius.circular(borderRadius)
              : null,
        ),
      ),
    );
  }
}
