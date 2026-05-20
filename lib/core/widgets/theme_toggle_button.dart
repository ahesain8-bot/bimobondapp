import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Theme.of(context).brightness == Brightness.dark
            ? LucideIcons.sun
            : LucideIcons.moon,
        color: Theme.of(context).colorScheme.primary,
      ),
      onPressed: () => context.read<ThemeCubit>().toggleTheme(),
    );
  }
}
