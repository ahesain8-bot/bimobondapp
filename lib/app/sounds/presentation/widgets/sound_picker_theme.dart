import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Applies the app light/dark theme (from [ThemeCubit]) to sound picker,
/// trim, and detail UI so accents still come from [ColorScheme].
class SoundPickerTheme extends StatelessWidget {
  const SoundPickerTheme({super.key, required this.child});

  final Widget child;

  /// Resolves [AppTheme] for the user's current theme preference.
  static ThemeData themeOf(BuildContext context) {
    ThemeMode mode;
    try {
      mode = context.read<ThemeCubit>().state;
    } catch (_) {
      mode = ThemeMode.system;
    }
    return ThemeCubit.isDarkActive(mode)
        ? AppTheme.darkTheme
        : AppTheme.lightTheme;
  }

  /// Accent for selected rows, CTAs, and waveform selection.
  static Color accentOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// Secondary accent (cover ring, links).
  static Color secondaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.secondary;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, mode) {
        final theme = ThemeCubit.isDarkActive(mode)
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        return Theme(
          data: theme,
          child: DefaultTextStyle(
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            child: IconTheme(
              data: theme.iconTheme.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
