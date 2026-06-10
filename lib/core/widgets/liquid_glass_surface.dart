import 'dart:ui';

import 'package:flutter/material.dart';

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
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
