import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WalletGlassStyle {
  const WalletGlassStyle._({required this.isDark, required this.colorScheme});

  factory WalletGlassStyle.of(BuildContext context) {
    final theme = Theme.of(context);
    return WalletGlassStyle._(
      isDark: theme.brightness == Brightness.dark,
      colorScheme: theme.colorScheme,
    );
  }

  final bool isDark;
  final ColorScheme colorScheme;

  Color get cardFill => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.white.withValues(alpha: 0.82);

  Color get cardBorder => isDark
      ? Colors.white.withValues(alpha: 0.18)
      : Colors.black.withValues(alpha: 0.06);

  Color get surfaceFill => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

  Color get surfaceBorder => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : colorScheme.outlineVariant.withValues(alpha: 0.4);

  Color get sheetFill =>
      isDark ? const Color(0xE6141414) : Colors.white.withValues(alpha: 0.92);

  Color get sheetBorder => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.06);

  Color get primaryText => isDark ? Colors.white : const Color(0xDE000000);

  Color get secondaryText =>
      isDark ? Colors.white.withValues(alpha: 0.62) : const Color(0x8A000000);

  Color get hintText =>
      isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0x73000000);
}

class WalletGlassTextField extends StatelessWidget {
  const WalletGlassTextField({
    required this.focusNode,
    required this.labelText,
    required this.onChanged,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
    super.key,
  });

  final FocusNode focusNode;
  final String labelText;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final Widget? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final style = WalletGlassStyle.of(context);

    return FormField<String>(
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(14),
              blurSigma: 16,
              backgroundColor: style.surfaceFill,
              borderColor: field.hasError
                  ? AppTheme.errorAccent.withValues(alpha: 0.55)
                  : style.surfaceBorder,
              child: TextField(
                focusNode: focusNode,
                keyboardType: keyboardType,
                inputFormatters: inputFormatters,
                obscureText: obscureText,
                textCapitalization: textCapitalization,
                onChanged: (value) {
                  field.didChange(value);
                  onChanged(value);
                  if (field.hasError) field.validate();
                },
                style: TextStyle(
                  color: style.primaryText,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: AppTheme.primaryColor,
                decoration: InputDecoration(
                  prefixIcon: prefixIcon,
                  labelText: labelText,
                  labelStyle: TextStyle(color: style.hintText),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            if (field.hasError && field.errorText?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: AppTheme.errorAccent, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}

class WalletGlassPrimaryButton extends StatelessWidget {
  const WalletGlassPrimaryButton({
    required this.onPressed,
    required this.child,
    this.enabled = true,
    this.height = AppSizes.buttonHeightSm,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final style = WalletGlassStyle.of(context);
    final backgroundColor = enabled ? AppTheme.primaryColor : style.surfaceFill;
    final borderColor = enabled
        ? AppTheme.primaryColor.withValues(alpha: 0.5)
        : style.surfaceBorder;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: LiquidGlassSurface(
          borderRadius: BorderRadius.circular(24),
          blurSigma: 16,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(24),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
