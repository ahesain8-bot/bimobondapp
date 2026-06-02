import 'package:bimobondapp/app/social/domain/entities/social_user_entity.dart';
import 'package:bimobondapp/core/constants/messages_layout_constants.dart';
import 'package:bimobondapp/core/navigation/user_profile_navigation.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class UserFollowerListTile extends StatelessWidget {
  const UserFollowerListTile({
    required this.user,
    required this.isSelf,
    this.isFollowLoading = false,
    this.onFollowTap,
    this.onProfileFollowStateChanged,
    super.key,
  });

  final SocialUserEntity user;
  final bool isSelf;
  final bool isFollowLoading;
  final VoidCallback? onFollowTap;
  final ValueChanged<bool>? onProfileFollowStateChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authorName = user.displayName;
    final handle = user.username?.trim();
    final buttonMode = user.followButtonMode(isSelf: isSelf);

    Future<void> openProfile() async {
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

    return InkWell(
      onTap: openProfile,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.p16,
          vertical: AppSizes.p12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SafeNetworkAvatar(
                  imageUrl: user.avatarUrl,
                  radius: 22,
                  fallbackText: authorName,
                ),
                PositionedDirectional(
                  end: -1,
                  bottom: -1,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: MessagesLayoutConstants.activityFollowersColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                      children: [
                        TextSpan(
                          text: authorName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ' ${l10n.userFollowerAction}',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (handle != null && handle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (buttonMode != SocialFollowButtonMode.hidden) ...[
              const SizedBox(width: AppSizes.p8),
              _FollowerActionButton(
                mode: buttonMode,
                isLoading: isFollowLoading,
                onPressed: onFollowTap,
                followLabel: l10n.messagesFollow,
                followBackLabel: l10n.connectionsFollowBack,
                followingLabel: l10n.messagesFollowing,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FollowerActionButton extends StatelessWidget {
  const _FollowerActionButton({
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
      height: 32,
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
          minimumSize: const Size(84, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 14,
                height: 14,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
