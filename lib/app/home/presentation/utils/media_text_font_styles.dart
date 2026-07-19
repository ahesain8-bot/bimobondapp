import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fancy font presets for the media text sticker editor (Aa cycle button).
class MediaTextFontStyle {
  const MediaTextFontStyle({
    required this.id,
    required this.label,
    this.fontFamily,
    this.fontWeight = FontWeight.w700,
    this.fontStyle = FontStyle.normal,
    this.letterSpacing = 0,
  });

  final String id;
  final String label;
  final String? fontFamily;
  final FontWeight fontWeight;
  final FontStyle fontStyle;
  final double letterSpacing;

  TextStyle resolve({
    required Color color,
    required double fontSize,
    TextDecoration decoration = TextDecoration.none,
    List<Shadow>? shadows,
  }) {
    final base = TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: color,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
    switch (id) {
      case 'pacifico':
        return GoogleFonts.pacifico(textStyle: base);
      case 'lobster':
        return GoogleFonts.lobster(textStyle: base);
      case 'dancing':
        return GoogleFonts.dancingScript(textStyle: base);
      case 'bebas':
        return GoogleFonts.bebasNeue(textStyle: base);
      case 'oswald':
        return GoogleFonts.oswald(textStyle: base);
      case 'playfair':
        return GoogleFonts.playfairDisplay(textStyle: base);
      case 'rubik_dirt':
        return GoogleFonts.rubikDirt(textStyle: base);
      case 'permanent':
        return GoogleFonts.permanentMarker(textStyle: base);
      case 'press_start':
        return GoogleFonts.pressStart2p(textStyle: base);
      default:
        return base.copyWith(fontFamily: fontFamily);
    }
  }
}

/// 10 fancy looks — cycled by the Aa button.
abstract final class MediaTextFontStyles {
  static const List<MediaTextFontStyle> all = [
    MediaTextFontStyle(
      id: 'classic',
      label: 'Classic',
      fontWeight: FontWeight.w800,
    ),
    MediaTextFontStyle(
      id: 'pacifico',
      label: 'Script',
      fontFamily: 'Pacifico',
      fontWeight: FontWeight.w400,
    ),
    MediaTextFontStyle(
      id: 'lobster',
      label: 'Lobster',
      fontFamily: 'Lobster',
      fontWeight: FontWeight.w400,
    ),
    MediaTextFontStyle(
      id: 'dancing',
      label: 'Dance',
      fontFamily: 'Dancing Script',
      fontWeight: FontWeight.w700,
    ),
    MediaTextFontStyle(
      id: 'bebas',
      label: 'Bebas',
      fontFamily: 'Bebas Neue',
      fontWeight: FontWeight.w400,
      letterSpacing: 1.5,
    ),
    MediaTextFontStyle(
      id: 'oswald',
      label: 'Oswald',
      fontFamily: 'Oswald',
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
    ),
    MediaTextFontStyle(
      id: 'playfair',
      label: 'Playfair',
      fontFamily: 'Playfair Display',
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
    ),
    MediaTextFontStyle(
      id: 'rubik_dirt',
      label: 'Dirt',
      fontFamily: 'Rubik Dirt',
      fontWeight: FontWeight.w400,
    ),
    MediaTextFontStyle(
      id: 'permanent',
      label: 'Marker',
      fontFamily: 'Permanent Marker',
      fontWeight: FontWeight.w400,
    ),
    MediaTextFontStyle(
      id: 'press_start',
      label: 'Pixel',
      fontFamily: 'Press Start 2P',
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
  ];

  static MediaTextFontStyle byId(String? id) {
    if (id == null || id.isEmpty) return all.first;
    return all.firstWhere((s) => s.id == id, orElse: () => all.first);
  }

  static int indexOfId(String? id) {
    final idx = all.indexWhere((s) => s.id == id);
    return idx < 0 ? 0 : idx;
  }

  /// Warm Google Fonts into the cache so the text editor opens instantly.
  static Future<void> preload() async {
    try {
      for (final style in all) {
        style.resolve(color: Colors.white, fontSize: 16);
      }
      await GoogleFonts.pendingFonts();
    } catch (_) {
      // Offline / first-run fetch failure — editor still works with fallbacks.
    }
  }
}
