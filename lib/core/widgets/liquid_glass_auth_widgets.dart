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

  Color get glassFill =>
      _isDark ? const Color(0x1AFFFFFF) : const Color(0x0F000000);

  Color get glassBorder =>
      _isDark ? const Color(0x26FFFFFF) : const Color(0x1A000000);

  Color get hintColor =>
      _isDark ? const Color(0x73FFFFFF) : const Color(0x73000000);

  Color get iconColor =>
      _isDark ? const Color(0xB3FFFFFF) : const Color(0xB3000000);

  Color get textColor => _isDark ? Colors.white : const Color(0xDE000000);
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
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              backgroundColor: style.glassFill,
              borderColor: field.hasError
                  ? AppTheme.errorAccent.withValues(alpha: 0.55)
                  : style.glassBorder,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: (value) {
                  field.didChange(value);
                  if (field.hasError) field.validate();
                },
                style: TextStyle(color: style.textColor),
                cursorColor: AppTheme.primaryColor,
                decoration: InputDecoration(
                  prefixIcon: icon != null
                      ? Icon(icon, color: style.iconColor)
                      : null,
                  hintText: hintText,
                  hintStyle: TextStyle(color: style.hintColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p16,
                    vertical: AppSizes.p16,
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
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator;

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
            LiquidGlassSurface(
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              backgroundColor: style.glassFill,
              borderColor: field.hasError
                  ? AppTheme.errorAccent.withValues(alpha: 0.55)
                  : style.glassBorder,
              child: TextField(
                controller: widget.controller,
                obscureText: _obscurePassword,
                onChanged: (value) {
                  field.didChange(value);
                  if (field.hasError) field.validate();
                },
                style: TextStyle(color: style.textColor),
                cursorColor: AppTheme.primaryColor,
                decoration: InputDecoration(
                  prefixIcon: Icon(LucideIcons.lock, color: style.iconColor),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                      color: style.iconColor,
                    ),
                  ),
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: style.hintColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.p16,
                    vertical: AppSizes.p16,
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
      height: 58,
      child: LiquidGlassSurface(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
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
      height: 56,
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
