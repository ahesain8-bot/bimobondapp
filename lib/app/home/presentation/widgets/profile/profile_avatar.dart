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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        StoryProfileAvatar(
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
        PositionedDirectional(
          bottom: 0,
          end: 0,
          child: GestureDetector(
            onTap: () => StoryFlow.start(context),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.plus,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
