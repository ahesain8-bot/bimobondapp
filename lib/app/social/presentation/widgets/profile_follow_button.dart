import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shared sizing so Follow / Follow back / Following look identical on user cards.
class ProfileFollowButtonSizes {
  static const double listHeight = 30;
  static const double listWidth = 92;
  static const double listFontSize = 12;
}

String profileFollowButtonLabel(
  AppLocalizations l10n, {
  required bool isFollowing,
  bool isFollowedBy = false,
}) {
  if (isFollowing) return l10n.messagesFollowing;
  if (isFollowedBy) return l10n.connectionsFollowBack;
  return l10n.messagesFollow;
}

class ProfileFollowButton extends StatelessWidget {
  const ProfileFollowButton({
    required this.isFollowing,
    required this.isLoading,
    this.isFollowedBy = false,
    this.onPressed,
    this.width,
    this.height = AppSizes.buttonHeightSm,
    this.fontSize = 14,
    super.key,
  });

  const ProfileFollowButton.listTile({
    required this.isFollowing,
    required this.isLoading,
    this.isFollowedBy = false,
    this.onPressed,
    super.key,
  })  : width = ProfileFollowButtonSizes.listWidth,
        height = ProfileFollowButtonSizes.listHeight,
        fontSize = ProfileFollowButtonSizes.listFontSize;

  final bool isFollowing;
  final bool isFollowedBy;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final label = profileFollowButtonLabel(
      l10n,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
    );
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
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p8),
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
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: CustomText(
                  label,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  color: foregroundColor,
                ),
              ),
      ),
    );
  }
}
