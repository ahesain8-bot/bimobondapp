import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_flow.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar_tap_handler.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.user,
    super.key,
  });

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ringColor = isDark
        ? theme.dividerColor.withValues(alpha: 0.35)
        : const Color(0xFFE3E3E4);
    final scaffold = theme.brightness == Brightness.light
        ? Colors.white
        : theme.scaffoldBackgroundColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 1),
          ),
          child: StoryProfileAvatar(
            userId: user.id,
            imageUrl: user.avatarUrl,
            fallbackText: user.username ?? user.fullName ?? 'User',
            radius: ProfileLayoutConstants.avatarRadius,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.08),
            username: user.username,
            fullName: user.fullName,
            onTap: () => handleProfileScreenAvatarTap(
              context,
              userId: user.id,
              avatarUrl: user.avatarUrl,
            ),
          ),
        ),
        PositionedDirectional(
          bottom: 2,
          end: 2,
          child: GestureDetector(
            onTap: () => StoryFlow.start(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: scaffold, width: 2.5),
              ),
              child: Icon(
                LucideIcons.plus,
                color: theme.colorScheme.onPrimary,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
