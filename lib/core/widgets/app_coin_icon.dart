import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// TikTok-style virtual coin accent used app-wide.
abstract final class AppCoinColors {
  AppCoinColors._();

  static const Color icon = Color(0xFFFACC15);
}

class AppCoinIcon extends StatelessWidget {
  const AppCoinIcon({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.coinStackIcon,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? AppCoinColors.icon,
        BlendMode.srcIn,
      ),
    );
  }
}

/// Coin amount label with the standard yellow coin icon.
class AppCoinAmount extends StatelessWidget {
  const AppCoinAmount({
    required this.text,
    super.key,
    this.iconSize = 16,
    this.style,
    this.spacing = 4,
    this.mainAxisSize = MainAxisSize.min,
    this.iconColor,
  });

  final String text;
  final double iconSize;
  final TextStyle? style;
  final double spacing;
  final MainAxisSize mainAxisSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      children: [
        AppCoinIcon(size: iconSize, color: iconColor),
        SizedBox(width: spacing),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
