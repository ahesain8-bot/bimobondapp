import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Forward chevron mirrored for LTR vs RTL locales.
class DirectionalChevronIcon extends StatelessWidget {
  const DirectionalChevronIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  static IconData iconData(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl
        ? LucideIcons.chevronLeft
        : LucideIcons.chevronRight;
  }

  @override
  Widget build(BuildContext context) {
    return Icon(iconData(context), size: size, color: color);
  }
}
