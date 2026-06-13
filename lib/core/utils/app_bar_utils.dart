import 'package:bimobondapp/core/constants/settings_layout_constants.dart';
import 'package:flutter/material.dart';

/// Grey bottom line for app bars that show a title.
class AppBarBottomDivider extends StatelessWidget implements PreferredSizeWidget {
  const AppBarBottomDivider({super.key});

  static const double height = 1;

  static double toolbarHeightWithDivider(
    double toolbarHeight, {
    bool showDivider = true,
  }) =>
      toolbarHeight + (showDivider ? height : 0);

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Divider(
      height: height,
      color: SettingsLayoutConstants.groupBorderColor(theme),
    );
  }
}
