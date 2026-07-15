import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/app_coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// TikTok-style profile top bar (light theme friendly).
class ProfileHeaderBar extends StatelessWidget {
  const ProfileHeaderBar({
    required this.onAddFriends,
    required this.onWallet,
    required this.onSettings,
    this.onShare,
    super.key,
  });

  final VoidCallback onAddFriends;
  final VoidCallback onWallet;
  final VoidCallback onSettings;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ProfileLayoutConstants.headerHorizontalPadding,
        vertical: ProfileLayoutConstants.headerVerticalPadding,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onAddFriends,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.userPlus,
              size: ProfileLayoutConstants.headerMenuIconSize,
              color: iconColor,
            ),
          ),
          IconButton(
            onPressed: onWallet,
            visualDensity: VisualDensity.compact,
            icon: AppCoinIcon(
              size: ProfileLayoutConstants.headerMenuIconSize,
              color: AppCoinColors.icon,
            ),
          ),
          const Spacer(),
          if (onShare != null)
            IconButton(
              onPressed: onShare,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.share,
                size: ProfileLayoutConstants.headerMenuIconSize,
                color: iconColor,
              ),
            ),
          IconButton(
            onPressed: onSettings,
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.menu,
              size: ProfileLayoutConstants.headerMenuIconSize,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
