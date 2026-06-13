import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/theme/cubit/locale_cubit.dart';
import 'package:bimobondapp/core/theme/cubit/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class LoginToolbar extends StatelessWidget {
  const LoginToolbar({
    required this.isArabic,
    required this.isDark,
    super.key,
  });

  final bool isArabic;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: () => context.read<ThemeCubit>().toggleTheme(),
          icon: Icon(
            isDark ? LucideIcons.sun : LucideIcons.moon,
            color: AppTheme.primaryColor,
            size: 22,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        TextButton(
          onPressed: () {
            context.read<LocaleCubit>().changeLanguage(isArabic ? 'en' : 'ar');
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            isArabic ? 'EN' : 'عربي',
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
