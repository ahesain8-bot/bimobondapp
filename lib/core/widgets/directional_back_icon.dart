import 'package:flutter/material.dart';

/// iOS-style back arrow mirrored for LTR vs RTL locales.
class DirectionalBackIcon extends StatelessWidget {
  const DirectionalBackIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  static IconData iconData(BuildContext context) {
    return Icons.arrow_back_ios_new_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData(context),
      size: size,
      color: color,
      // matchTextDirection: true,
    );
  }
}
