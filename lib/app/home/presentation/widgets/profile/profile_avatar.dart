import 'package:bimobondapp/app/auth/domain/entities/user_entity.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
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

    return SafeNetworkAvatar(
      imageUrl: user.avatarUrl,
      radius: ProfileLayoutConstants.avatarRadius,
      fallbackText: user.username,
      backgroundColor: theme.dividerColor.withValues(alpha: 0.08),
    );
  }
}
