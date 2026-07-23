import 'package:flutter/material.dart';

/// Visual treatment cycled by the TikTok-style "A" button
/// (none → solid rounded background → white outline → …).
enum MediaTextLook {
  none,
  background,
  outline,
}

/// A single editable text sticker placed on a photo in the media studio editor.
///
/// [center] is stored as a fraction (0..1) of the **media image/video frame**
/// so overlays stay locked to image content across letterboxing, filter
/// previews, and container resizes — and map 1:1 when baking.
class MediaTextOverlay {
  const MediaTextOverlay({
    required this.id,
    required this.text,
    this.center = const Offset(0.5, 0.4),
    this.color = Colors.white,
    this.backgroundColor,
    this.fontSize = 28,
    this.textAlign = TextAlign.center,
    this.fontWeight = FontWeight.w700,
    this.fontStyle = FontStyle.normal,
    this.textDecoration = TextDecoration.none,
    this.fontFamily,
    this.fontStyleId = 'classic',
    this.letterSpacing = 0,
    this.look = MediaTextLook.none,
  });

  final String id;
  final String text;

  /// Fractional center within the media frame (0..1, 0..1).
  final Offset center;

  final Color color;

  /// Optional highlight background behind the text.
  final Color? backgroundColor;

  /// Logical font size measured against the preview box height.
  final double fontSize;

  final TextAlign textAlign;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final TextDecoration textDecoration;

  /// Bundled / Google font family name, or null for the platform default.
  final String? fontFamily;

  /// Id from [MediaTextFontStyles] (e.g. `pacifico`, `lobster`).
  final String fontStyleId;

  final double letterSpacing;

  /// none / solid rounded fill / white outline.
  final MediaTextLook look;

  /// Horizontal snap used when the user picks left / center / right alignment.
  static double dxForAlign(TextAlign align) {
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        return 0.14;
      case TextAlign.right:
      case TextAlign.end:
        return 0.86;
      default:
        return 0.5;
    }
  }

  /// Next look in the TikTok-style cycle.
  static MediaTextLook nextLook(MediaTextLook current) {
    switch (current) {
      case MediaTextLook.none:
        return MediaTextLook.background;
      case MediaTextLook.background:
        return MediaTextLook.outline;
      case MediaTextLook.outline:
        return MediaTextLook.none;
    }
  }

  /// Fill color behind text when [look] is [MediaTextLook.background].
  Color get resolvedBackground {
    if (look != MediaTextLook.background) {
      return backgroundColor ?? Colors.transparent;
    }
    return backgroundColor ?? color;
  }

  /// Text fill color after applying look (contrast on solid background).
  Color get resolvedTextColor {
    if (look != MediaTextLook.background) return color;
    final bg = resolvedBackground;
    final luminance = bg.computeLuminance();
    return luminance > 0.55 ? Colors.black : Colors.white;
  }

  bool get hasOutline => look == MediaTextLook.outline;

  MediaTextOverlay copyWith({
    String? text,
    Offset? center,
    Color? color,
    Object? backgroundColor = _sentinel,
    double? fontSize,
    TextAlign? textAlign,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextDecoration? textDecoration,
    Object? fontFamily = _sentinel,
    String? fontStyleId,
    double? letterSpacing,
    MediaTextLook? look,
  }) {
    return MediaTextOverlay(
      id: id,
      text: text ?? this.text,
      center: center ?? this.center,
      color: color ?? this.color,
      backgroundColor: backgroundColor == _sentinel
          ? this.backgroundColor
          : backgroundColor as Color?,
      fontSize: fontSize ?? this.fontSize,
      textAlign: textAlign ?? this.textAlign,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      textDecoration: textDecoration ?? this.textDecoration,
      fontFamily: fontFamily == _sentinel
          ? this.fontFamily
          : fontFamily as String?,
      fontStyleId: fontStyleId ?? this.fontStyleId,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      look: look ?? this.look,
    );
  }

  static const Object _sentinel = Object();
}
