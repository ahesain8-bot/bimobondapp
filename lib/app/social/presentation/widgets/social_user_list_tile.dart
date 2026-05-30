import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/custom_text.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class SocialUserListTile extends StatelessWidget {
  const SocialUserListTile({
    required this.user,
    required this.isSelf,
    this.isFollowLoading = false,
    this.onFollowTap,
    this.onTap,
    this.onProfileFollowStateChanged,
    super.key,
  });

  final SocialUserEntity user;
  final bool isSelf;
  final bool isFollowLoading;
  final VoidCallback? onFollowTap;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onProfileFollowStateChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final handle = user.username?.trim();
    final buttonMode = user.followButtonMode(isSelf: isSelf);

    Future<void> openProfile() async {
      if (onTap != null) {
        onTap!();
        return;
      }
      final isFollowing = await openUserProfile(
        context,
        userId: user.id,
        username: user.username,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        isFollowing: user.isFollowing,
      );
      if (isFollowing != null) {
        onProfileFollowStateChanged?.call(isFollowing);
      }
    }

    return ListTile(
      onTap: openProfile,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.p16,
        vertical: AppSizes.p4,
      ),
      leading: SafeNetworkAvatar(
        imageUrl: user.avatarUrl,
        radius: 24,
        fallbackText: user.displayName,
      ),
      title: Text(
        user.fullName ?? user.username ?? user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: handle != null && handle.isNotEmpty
          ? CustomText('@$handle', fontSize: 13, variant: TextVariant.secondary)
          : null,
      trailing: buttonMode == SocialFollowButtonMode.hidden
          ? null
          : _SocialFollowButton(
              mode: buttonMode,
              isLoading: isFollowLoading,
              onPressed: onFollowTap,
              followLabel: l10n.messagesFollow,
              followBackLabel: l10n.connectionsFollowBack,
              followingLabel: l10n.messagesFollowing,
            ),
    );
  }
}

class _SocialFollowButton extends StatelessWidget {
  const _SocialFollowButton({
    required this.mode,
    required this.isLoading,
    required this.onPressed,
    required this.followLabel,
    required this.followBackLabel,
    required this.followingLabel,
  });

  final SocialFollowButtonMode mode;
  final bool isLoading;
  final VoidCallback? onPressed;
  final String followLabel;
  final String followBackLabel;
  final String followingLabel;

  bool get _isFollowing => mode == SocialFollowButtonMode.following;

  String get _label {
    switch (mode) {
      case SocialFollowButtonMode.followBack:
        return followBackLabel;
      case SocialFollowButtonMode.following:
        return followingLabel;
      case SocialFollowButtonMode.follow:
      case SocialFollowButtonMode.hidden:
        return followLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 34,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: _isFollowing
              ? theme.dividerColor.withValues(alpha: 0.15)
              : theme.colorScheme.primary,
          foregroundColor: _isFollowing
              ? theme.colorScheme.onSurface
              : Colors.white,
          disabledBackgroundColor: _isFollowing
              ? theme.dividerColor.withValues(alpha: 0.15)
              : theme.colorScheme.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12),
          minimumSize: const Size(88, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _isFollowing
                      ? theme.colorScheme.onSurface
                      : Colors.white,
                ),
              )
            : Text(
                _label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
