import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/app/home/presentation/utils/active_stories_registry.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_ring_avatar.dart';
import 'package:bimobondapp/core/data/viewed_stories_store.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

/// Profile avatar with optional story ring; tap opens active stories or profile.
class StoryProfileAvatar extends StatelessWidget {
  const StoryProfileAvatar({
    required this.userId,
    required this.fallbackText,
    this.imageUrl,
    this.radius = 24,
    this.backgroundColor,
    this.onTap,
    this.username,
    this.fullName,
    this.isFollowing,
    super.key,
  });

  final String? userId;
  final String? imageUrl;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final String? username;
  final String? fullName;
  final bool? isFollowing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final registry = auth_di.sl<ActiveStoriesRegistry>();
    final viewedStore = auth_di.sl<ViewedStoriesStore>();

    return ListenableBuilder(
      listenable: Listenable.merge([registry, viewedStore]),
      builder: (context, _) {
        final id = userId?.trim() ?? '';
        final group = id.isEmpty ? null : registry.groupFor(id);
        final hasStories =
            group != null && registry.activeStoriesFor(id).isNotEmpty;
        final isViewed = hasStories && viewedStore.isGroupFullyViewed(group!.stories);

        Widget avatar = hasStories
            ? StoryRingAvatar(
                imageUrl: imageUrl,
                fallbackText: fallbackText,
                theme: theme,
                radius: radius,
                isViewed: isViewed,
              )
            : SafeNetworkAvatar(
                imageUrl: imageUrl,
                radius: radius,
                fallbackText: fallbackText,
                backgroundColor: backgroundColor,
              );

        final handler = onTap ??
            (id.isEmpty
                ? null
                : () {
                    openUserActiveStoriesOrProfile(
                      context,
                      userId: id,
                      username: username,
                      fullName: fullName,
                      avatarUrl: imageUrl,
                      isFollowing: isFollowing,
                    );
                  });

        if (handler == null) return avatar;
        return GestureDetector(onTap: handler, child: avatar);
      },
    );
  }
}
