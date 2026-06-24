import 'package:flutter/material.dart';

enum StoryTextFontStyle {
  classic,
  modern,
  typewriter,
  strong,
  neon,
}

enum StoryTextBackgroundMode {
  none,
  translucent,
  solid,
}

enum StoryTextAlignment {
  left,
  center,
  right;

  TextAlign get textAlign => switch (this) {
        StoryTextAlignment.left => TextAlign.left,
        StoryTextAlignment.center => TextAlign.center,
        StoryTextAlignment.right => TextAlign.right,
      };

  StoryTextAlignment next() => switch (this) {
        StoryTextAlignment.left => StoryTextAlignment.center,
        StoryTextAlignment.center => StoryTextAlignment.right,
        StoryTextAlignment.right => StoryTextAlignment.left,
      };

  static StoryTextAlignment fromJson(String? raw) => switch (raw) {
        'left' => StoryTextAlignment.left,
        'right' => StoryTextAlignment.right,
        _ => StoryTextAlignment.center,
      };

  String get jsonValue => name;
}

class StoryTextStyleKit {
  StoryTextStyleKit._();

  static const palette = <Color>[
    Colors.white,
    Colors.black,
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF5AC8FA),
    Color(0xFF007AFF),
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
    Color(0xFFAF52DE),
    Color(0xFFFFFC00),
  ];

  static StoryTextFontStyle cycleFont(StoryTextFontStyle current) {
    const values = StoryTextFontStyle.values;
    return values[(values.indexOf(current) + 1) % values.length];
  }

  static StoryTextBackgroundMode cycleBackground(StoryTextBackgroundMode current) {
    const values = StoryTextBackgroundMode.values;
    return values[(values.indexOf(current) + 1) % values.length];
  }

  static TextStyle resolve({
    required StoryTextFontStyle fontStyle,
    required Color textColor,
    required double scale,
    required bool withShadow,
  }) {
    final size = 28.0 * scale;
    final shadow = withShadow
        ? const [
            Shadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 1),
            ),
          ]
        : null;

    return switch (fontStyle) {
      StoryTextFontStyle.classic => TextStyle(
          color: textColor,
          fontSize: size,
          height: 1.15,
          fontFamily: 'serif',
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          shadows: shadow,
        ),
      StoryTextFontStyle.modern => TextStyle(
          color: textColor,
          fontSize: size,
          height: 1.15,
          fontFamily: 'Jannat',
          fontWeight: FontWeight.w600,
          shadows: shadow,
        ),
      StoryTextFontStyle.typewriter => TextStyle(
          color: textColor,
          fontSize: size,
          height: 1.15,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          shadows: shadow,
        ),
      StoryTextFontStyle.strong => TextStyle(
          color: textColor,
          fontSize: size,
          height: 1.15,
          fontFamily: 'Jannat',
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          shadows: shadow,
        ),
      StoryTextFontStyle.neon => TextStyle(
          color: textColor,
          fontSize: size,
          height: 1.15,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: textColor.withValues(alpha: 0.85), blurRadius: 12),
            Shadow(color: textColor.withValues(alpha: 0.55), blurRadius: 24),
            if (withShadow)
              const Shadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
          ],
        ),
    };
  }

  static Color contrastingTextOn(Color background) =>
      background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}
