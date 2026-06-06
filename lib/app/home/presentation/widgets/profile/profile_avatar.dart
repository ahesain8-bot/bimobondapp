import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_avatar_tap_handler.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.user,
    super.key,
  });

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoryProfileAvatar(
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
    );
  }
}
