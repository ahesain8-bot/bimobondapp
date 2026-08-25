import 'package:flutter/material.dart';

/// TikTok-style dark editor tokens.
abstract final class TemplateEditorTheme {
  static const background = Color(0xFF000000);
  static const panel = Color(0xFF1A1A1A);
  static const panelElevated = Color(0xFF252525);
  static const border = Color(0x33FFFFFF);
  static const textPrimary = Colors.white;
  static const textMuted = Color(0x99FFFFFF);
  static const accent = Color(0xFFFF2D55);
  static const audioTrack = Color(0xFF5B9BD5);
  static const textTrack = Color(0xFFE91E8C);
  static const stickerTrack = Color(0xFFB39DDB);
  static const filterTrack = Color(0xFFFF8A65);
  static const effectTrack = Color(0xFFFFB74D);
  static const slotSelectedBorder = Colors.white;

  static String formatTime(double seconds) {
    final totalMs = (seconds * 1000).round().clamp(0, 359999999);
    final s = totalMs ~/ 1000;
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
  }
}
