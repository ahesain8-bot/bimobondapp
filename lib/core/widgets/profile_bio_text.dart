import 'package:flutter/material.dart';

/// Profile bio with a fixed reserved space so the header never shifts.
/// Display is capped at [maxLength] characters (matches the edit limit).
class ProfileBioText extends StatelessWidget {
  const ProfileBioText({
    required this.bio,
    required this.placeholder,
    this.onTap,
    super.key,
  });

  /// Max characters shown / allowed for a bio.
  static const int maxLength = 50;

  /// Reserved height — fits 2 lines at 14px so layout stays stable.
  static const double fixedHeight = 40;

  final String? bio;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = bio?.trim() ?? '';
    final hasBio = trimmed.isNotEmpty;
    final display = !hasBio
        ? placeholder
        : trimmed.length > maxLength
        ? '${trimmed.substring(0, maxLength)}…'
        : trimmed;
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return SizedBox(
      height: fixedHeight,
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: hasBio ? theme.colorScheme.onSurface : secondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
