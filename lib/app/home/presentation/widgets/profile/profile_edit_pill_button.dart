import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Compact TikTok-style "Edit" pill beside the display name.
class ProfileEditPillButton extends StatelessWidget {
  const ProfileEditPillButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85)
        : ProfileLayoutConstants.editPillBackgroundLight;

    return Semantics(
      button: true,
      label: l10n.edit,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(
          ProfileLayoutConstants.editPillHeight / 2,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(
            ProfileLayoutConstants.editPillHeight / 2,
          ),
          child: SizedBox(
            height: ProfileLayoutConstants.editPillHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Text(
                  l10n.edit,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
