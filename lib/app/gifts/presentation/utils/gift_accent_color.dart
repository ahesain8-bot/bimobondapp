import 'package:flutter/material.dart';

Color giftAccentColor(String? hex, {Color fallback = const Color(0xFF008080)}) {
  if (hex == null || hex.trim().isEmpty) return fallback;
  var value = hex.trim();
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return fallback;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

/// Swirling neon/silk stops for audio CD art from catalog [color] hex.
List<Color> giftSilkDiscColors(
  String? hex, {
  Color fallback = const Color(0xFF00CED1),
}) {
  final base = giftAccentColor(hex, fallback: fallback);
  final hsl = HSLColor.fromColor(base);
  final h = hsl.hue;
  final s = hsl.saturation.clamp(0.45, 1.0);
  final l = hsl.lightness.clamp(0.35, 0.72);

  Color at(double hueShift, {double? sat, double? light}) {
    return HSLColor.fromAHSL(
      1,
      (h + hueShift) % 360,
      (sat ?? s).clamp(0.0, 1.0),
      (light ?? l).clamp(0.0, 1.0),
    ).toColor();
  }

  return [
    Color.lerp(at(0, light: (l + 0.26).clamp(0.0, 0.92)), Colors.white, 0.35)!,
    at(18, sat: 0.98, light: (l + 0.12).clamp(0.0, 0.85)),
    base,
    at(-28, sat: 0.95),
    at(42, sat: 0.9, light: (l - 0.04).clamp(0.0, 0.75)),
    at(-55, sat: 0.88, light: (l + 0.08).clamp(0.0, 0.8)),
    Color.lerp(at(0, light: (l + 0.26).clamp(0.0, 0.92)), Colors.white, 0.35)!,
  ];
}
