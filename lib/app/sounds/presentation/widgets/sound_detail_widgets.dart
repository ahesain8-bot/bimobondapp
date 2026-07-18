import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_video_background.dart';
import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class SoundSpinningDisc extends StatelessWidget {
  const SoundSpinningDisc({
    super.key,
    required this.rotation,
    required this.size,
    this.coverUrl,
    this.isPlaying = false,
    this.onTap,
  });

  final Animation<double> rotation;
  final double size;
  final String? coverUrl;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: rotation,
        builder: (context, child) {
          return Transform.rotate(
            angle: isPlaying ? rotation.value * 2 * 3.14159 : 0,
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: coverUrl != null && coverUrl!.isNotEmpty
                ? SafeNetworkImage(
                    imageUrl: coverUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying ? LucideIcons.pause : LucideIcons.music,
                        color: Colors.white,
                        size: size * 0.28,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class SoundDetailVideoGrid extends StatelessWidget {
  const SoundDetailVideoGrid({super.key, required this.posts});

  final List<SoundPostPreviewEntity> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: ProfileLayoutConstants.gridSpacing,
        mainAxisSpacing: ProfileLayoutConstants.gridSpacing,
        childAspectRatio: ProfileLayoutConstants.gridAspectRatio,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () => openPostById(context, post.id),
          child: _SoundPostGridTile(post: post),
        );
      },
    );
  }
}

class _SoundPostGridTile extends StatelessWidget {
  const _SoundPostGridTile({required this.post});

  final SoundPostPreviewEntity post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverUrl = post.resolvedCoverUrl;
    final videoUrl = post.resolvedVideoUrl;
    final hasCover = coverUrl != null && coverUrl.isNotEmpty;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    // Photos: never treat as video when we only have a cover image.
    final isVideo = post.isVideo && hasVideo;
    final placeholderColor = theme.dividerColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final showViewCount = isVideo && post.viewCount > 0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Profile-style cover: image first, muted video preview when available.
        ColoredBox(
          color: hasCover || !isVideo ? placeholderColor : Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                SafeNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorIcon: Icons.image_outlined,
                  showLoadingIndicator: false,
                ),
              if (hasVideo)
                ProfileGridVideoBackground(
                  videoUrl: videoUrl,
                  posterUrl: coverUrl,
                )
              else if (!hasCover && isVideo)
                const VideoPostPreviewPlaceholder(
                  iconSize: ProfileLayoutConstants.gridPlaceholderIconSize,
                )
              else if (!hasCover)
                Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: ProfileLayoutConstants.gridPlaceholderIconSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        ),
        if (!isVideo)
          Center(
            child: Icon(
              LucideIcons.image,
              size: 18,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0x99000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        if (showViewCount) ...[
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 6,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.play,
                  size: ProfileLayoutConstants.gridViewCountIconSize,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  formatCompactCount(post.viewCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: ProfileLayoutConstants.gridViewCountFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    shadows: [Shadow(color: Color(0x80000000), blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
