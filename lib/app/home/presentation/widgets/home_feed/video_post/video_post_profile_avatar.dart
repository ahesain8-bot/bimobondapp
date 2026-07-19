import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:flutter/material.dart';

class VideoPostProfileAvatar extends StatelessWidget {
  const VideoPostProfileAvatar({
    required this.avatarUrl,
    required this.username,
    required this.fullName,
    required this.userId,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.showFollowBadge,
    required this.onTap,
    required this.onFollow,
    super.key,
  });

  final String? avatarUrl;
  final String? username;
  final String? fullName;
  final String? userId;
  final bool isFollowing;
  final bool isFollowLoading;
  final bool showFollowBadge;
  final VoidCallback onTap;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        StoryProfileAvatar(
          userId: userId,
          imageUrl: avatarUrl,
          fallbackText: username ?? 'User',
          radius: VideoPostLayoutConstants.profileAvatarRadius,
          backgroundColor: Colors.white24,
          username: username,
          fullName: fullName,
          isFollowing: isFollowing,
          onTap: onTap,
        ),
        if (showFollowBadge)
          Positioned(
            bottom: -8,
            child: GestureDetector(
              onTap: isFollowing ? null : onFollow,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  gradient: isFollowing
                      ? null
                      : LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: isFollowing ? Colors.white : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isFollowing ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: isFollowLoading
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        isFollowing ? Icons.check : Icons.add,
                        color: isFollowing
                            ? theme.colorScheme.primary
                            : Colors.white,
                        size: 12,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
