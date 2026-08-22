import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../domain/entities/live_entity.dart';
import 'fallback_media.dart';
import 'live_badge.dart';

class LiveCard extends StatelessWidget {
  final LiveEntity live;
  final VoidCallback? onTap;
  final double? height;

  const LiveCard({super.key, required this.live, this.onTap, this.height});

  @override
  Widget build(BuildContext context) {
    final cardHeight = height ?? context.screenHeight * 0.58;

    return GestureDetector(
          onTap: onTap,
          child: Container(
            height: cardHeight,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'live_thumb_${live.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildBackgroundImage(),
                    ),
                  ),
                  _buildGradientOverlay(),
                  _buildContent(),
                  const Positioned(top: 12, left: 12, child: LiveBadge()),
                  _buildViewerCount(),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 350.ms)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 350.ms,
        );
  }

  Widget _buildBackgroundImage() {
    return CachedNetworkImage(
      imageUrl: live.thumbnailUrl ?? '',
      fit: BoxFit.cover,
      memCacheWidth: 800,
      placeholder: (context, url) => FallbackLiveCover(
        seed: live.id,
        category: live.category,
        hostInitial: live.hostName,
        title: live.title,
      ),
      errorWidget: (context, url, error) => FallbackLiveCover(
        seed: live.id,
        category: live.category,
        hostInitial: live.hostName,
        title: live.title,
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.15),
              Colors.transparent,
              Colors.black.withOpacity(0.35),
              Colors.black.withOpacity(0.82),
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Hero(
                tag: 'live_avatar_${live.id}',
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: live.hostAvatar ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => FallbackAvatar(
                        seed: live.hostId,
                        name: live.hostName,
                        radius: 20,
                      ),
                      errorWidget: (_, __, ___) => FallbackAvatar(
                        seed: live.hostId,
                        name: live.hostName,
                        radius: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${live.hostName}',
                      style: AppTextStyles.hostName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      live.title,
                      style: AppTextStyles.liveTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  live.category,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.favorite,
                size: 14,
                color: AppColors.secondary.withOpacity(0.9),
              ),
              const SizedBox(width: 4),
              Text(
                live.likeCount.formatNumber,
                style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewerCount() {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              live.viewerCount.formatNumber,
              style: AppTextStyles.viewerCount,
            ),
          ],
        ),
      ),
    );
  }
}
