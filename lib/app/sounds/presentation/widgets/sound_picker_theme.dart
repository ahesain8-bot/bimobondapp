import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Forces sound picker / trim / detail UI onto [AppTheme.lightTheme] so
/// surfaces stay white and accents come from the app [ColorScheme].
class SoundPickerTheme extends StatelessWidget {
  const SoundPickerTheme({super.key, required this.child});

  final Widget child;

  static ThemeData get theme => AppTheme.lightTheme;

  /// Accent for selected rows, CTAs, and waveform selection.
  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Secondary accent (cover ring, links).
  static Color secondaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        child: IconTheme(
          data: theme.iconTheme.copyWith(color: theme.colorScheme.onSurface),
          child: child,
        ),
      ),
    );
  }
}
