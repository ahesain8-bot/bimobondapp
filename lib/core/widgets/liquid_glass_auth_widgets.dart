import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AuthGlassStyle {
  const AuthGlassStyle._(this._isDark);

  factory AuthGlassStyle.of(BuildContext context) {
    return AuthGlassStyle._(Theme.of(context).brightness == Brightness.dark);
  }

  final bool _isDark;

  Color get fieldFill =>
      _isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F1F2);

  Color get fieldDivider =>
      _isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000);

  Color get hintColor =>
      _isDark ? const Color(0x73FFFFFF) : const Color(0x73000000);

  Color get iconColor =>
      _isDark ? const Color(0xB3FFFFFF) : const Color(0xB3000000);

  Color get textColor => _isDark ? Colors.white : const Color(0xFF161823);

  // Legacy aliases used outside auth inputs.
  Color get glassFill => fieldFill;
  Color get glassBorder => fieldDivider;
}

TextStyle authFieldTextStyle(AuthGlassStyle style) {
  return TextStyle(
    color: style.textColor,
    fontSize: AppSizes.authControlFontSize,
    fontWeight: FontWeight.w500,
    height: 1.0,
  );
}

TextStyle authFieldHintStyle(AuthGlassStyle style) {
  return TextStyle(
    color: style.hintColor,
    fontSize: AppSizes.authControlFontSize,
    fontWeight: FontWeight.w400,
    height: 1.0,
  );
}

InputDecoration authFieldDecoration({
  required AuthGlassStyle style,
  required String hintText,
  IconData? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  BoxConstraints? suffixIconConstraints,
}) {
  return InputDecoration(
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: style.iconColor, size: 20)
        : null,
    suffixIcon: suffixIcon,
    suffixIconConstraints: suffixIconConstraints,
    hintText: hintText,
    hintStyle: authFieldHintStyle(style),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    isCollapsed: true,
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
  );
}

class AuthFieldContainer extends StatelessWidget {
  const AuthFieldContainer({
    required this.hasError,
    required this.child,
    super.key,
  });

  final bool hasError;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);

    return Container(
      width: double.infinity,
      height: AppSizes.authControlHeight,
      decoration: BoxDecoration(
        color: style.fieldFill,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: hasError
            ? Border.all(
                color: AppTheme.errorAccent.withValues(alpha: 0.55),
              )
            : null,
      ),
      child: child,
    );
  }
}

class LiquidGlassAuthTextField extends StatelessWidget {
  const LiquidGlassAuthTextField({
    required this.controller,
    required this.hintText,
    this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);

    return FormField<String>(
      validator: validator,
      initialValue: controller.text,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthFieldContainer(
              hasError: field.hasError,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) {
                  field.didChange(value);
                  if (field.hasError) field.validate();
                },
                style: authFieldTextStyle(style),
                cursorColor: AppTheme.primaryColor,
                decoration: authFieldDecoration(
                  style: style,
                  hintText: hintText,
                  prefixIcon: icon,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: icon != null ? AppSizes.p12 : AppSizes.p16,
                    vertical: AppSizes.p12,
                  ),
                ),
              ),
            ),
            if (field.hasError && field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSizes.p6,
                  left: AppSizes.p4,
                ),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: AppTheme.errorAccent,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class LiquidGlassAuthPasswordField extends StatefulWidget {
  const LiquidGlassAuthPasswordField({
    required this.controller,
    required this.hintText,
    this.validator,
    this.maxLength,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;
  final int? maxLength;

  @override
  State<LiquidGlassAuthPasswordField> createState() =>
      _LiquidGlassAuthPasswordFieldState();
}

class _LiquidGlassAuthPasswordFieldState
    extends State<LiquidGlassAuthPasswordField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);

    return FormField<String>(
      validator: widget.validator,
      initialValue: widget.controller.text,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthFieldContainer(
              hasError: field.hasError,
              child: TextField(
                controller: widget.controller,
                obscureText: _obscurePassword,
                maxLength: widget.maxLength,
                textAlignVertical: TextAlignVertical.center,
                onChanged: (value) {
                  field.didChange(value);
                  if (field.hasError) field.validate();
                },
                style: authFieldTextStyle(style),
                cursorColor: AppTheme.primaryColor,
                decoration: authFieldDecoration(
                  style: style,
                  hintText: widget.hintText,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: style.iconColor,
                      size: 20,
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: AppSizes.authControlHeight,
                  ),
                ).copyWith(counterText: ''),
              ),
            ),
            if (field.hasError && field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSizes.p6,
                  left: AppSizes.p4,
                ),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: AppTheme.errorAccent,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class LiquidGlassAuthPrimaryButton extends StatelessWidget {
  const LiquidGlassAuthPrimaryButton({
    required this.onPressed,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);
    final backgroundColor = enabled ? AppTheme.primaryColor : style.glassFill;
    final borderColor = enabled
        ? AppTheme.primaryColor.withValues(alpha: 0.5)
        : style.glassBorder;

    return SizedBox(
      width: double.infinity,
      height: AppSizes.authControlHeight,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassAuthOutlinedButton extends StatelessWidget {
  const LiquidGlassAuthOutlinedButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);

    return SizedBox(
      width: double.infinity,
      height: AppSizes.authControlHeight,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        backgroundColor: style.glassFill,
        borderColor: style.glassBorder,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassAuthIconButton extends StatelessWidget {
  const LiquidGlassAuthIconButton({
    required this.onPressed,
    required this.child,
    this.size = 54,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        backgroundColor: style.glassFill,
        borderColor: style.glassBorder,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
