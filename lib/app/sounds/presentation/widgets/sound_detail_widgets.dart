import 'package:bimobondapp/app/sounds/domain/entities/sound_entity.dart';
import 'package:bimobondapp/core/navigation/post_navigation.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
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
  const SoundDetailVideoGrid({
    super.key,
    required this.posts,
  });

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
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.72,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final thumb = post.resolvedThumbnailUrl;
        return GestureDetector(
          onTap: () => openPostById(context, post.id),
          child: ColoredBox(
            color: Colors.white.withValues(alpha: 0.08),
            child: thumb != null
                ? Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const Icon(
                      LucideIcons.video,
                      color: Colors.white54,
                    ),
                  )
                : const Icon(LucideIcons.video, color: Colors.white54),
          ),
        );
      },
    );
  }
}
