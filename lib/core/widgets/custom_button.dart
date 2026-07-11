import 'package:bimobondapp/core/theme/app_theme.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/liquid_glass_auth_widgets.dart';
import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = AuthGlassStyle.of(context);

    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeightMd,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isLoading ? style.glassFill : AppTheme.primaryColor,
          disabledBackgroundColor: style.glassFill,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          side: BorderSide(
            color: isLoading
                ? style.glassBorder
                : AppTheme.primaryColor.withValues(alpha: 0.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          ),
        ),
        child: isLoading
            ? const CustomLoadingWidget(size: 32)
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
