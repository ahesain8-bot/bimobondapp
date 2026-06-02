import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ProfileFollowButton extends StatelessWidget {
  const ProfileFollowButton({
    required this.isFollowing,
    required this.isLoading,
    this.onPressed,
    this.width,
    this.height = 40,
    this.fontSize = 14,
    super.key,
  });

  final bool isFollowing;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final foregroundColor = isFollowing
        ? theme.colorScheme.onSurface
        : Colors.white;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing
              ? theme.dividerColor.withValues(alpha: 0.2)
              : theme.colorScheme.primary,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: isFollowing
              ? theme.dividerColor.withValues(alpha: 0.2)
              : theme.colorScheme.primary.withValues(alpha: 0.5),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: height * 0.45,
                height: height * 0.45,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : CustomText(
                isFollowing ? l10n.messagesFollowing : l10n.messagesFollow,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                color: foregroundColor,
              ),
      ),
    );
  }
}
