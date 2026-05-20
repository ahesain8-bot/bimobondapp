import 'package:flutter/material.dart';

enum TextVariant { primary, secondary, muted }

class CustomText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final TextVariant variant;

  const CustomText(
    this.text, {
    super.key,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.textAlign,
    this.variant = TextVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color defaultColor;
    switch (variant) {
      case TextVariant.primary:
        defaultColor = isDark ? Colors.white : Colors.black87;
        break;
      case TextVariant.secondary:
        defaultColor = isDark ? Colors.white70 : Colors.black54;
        break;
      case TextVariant.muted:
        defaultColor = isDark ? Colors.white54 : Colors.black45;
        break;
    }

    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: color ?? defaultColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }
}
