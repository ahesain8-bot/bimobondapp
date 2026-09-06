import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/live_entity.dart';

/// Horizontal TikTok-style LIVE stories strip (finite — no wrap / loop).
class LiveStoriesStrip extends StatelessWidget {
  const LiveStoriesStrip({
    super.key,
    required this.lives,
    required this.selectedIndex,
    required this.onLiveTap,
    this.onGoLiveTap,
    this.isLoadingMore = false,
  });

  final List<LiveEntity> lives;
  final int selectedIndex;
  final ValueChanged<int> onLiveTap;
  final VoidCallback? onGoLiveTap;
  final bool isLoadingMore;

  static const double _avatarSize = 64;
  static const double _itemWidth = 76;

  @override
  Widget build(BuildContext context) {
    final itemCount = lives.length + (onGoLiveTap != null ? 1 : 0) +
        (isLoadingMore ? 1 : 0);

    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // Finite list — never duplicates items or wraps to index 0.
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (onGoLiveTap != null && index == 0) {
            return _GoLiveStory(onTap: onGoLiveTap!);
          }

          final liveOffset = onGoLiveTap != null ? 1 : 0;
          final liveIndex = index - liveOffset;

          if (liveIndex >= lives.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 18),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              ),
            );
          }

          final live = lives[liveIndex];
          return _LiveStoryItem(
            live: live,
            selected: liveIndex == selectedIndex,
            onTap: () => onLiveTap(liveIndex),
          );
        },
      ),
    );
  }
}

class _GoLiveStory extends StatelessWidget {
  const _GoLiveStory({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: LiveStoriesStrip._itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: LiveStoriesStrip._avatarSize,
              height: LiveStoriesStrip._avatarSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.secondary,
                        width: 2.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: const CircleAvatar(
                      backgroundColor: AppColors.surface,
                      child: Icon(
                        Icons.person,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Go LIVE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStoryItem extends StatelessWidget {
  const _LiveStoryItem({
    required this.live,
    required this.selected,
    required this.onTap,
  });

  final LiveEntity live;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = live.hostName.trim().isEmpty ? 'LIVE' : live.hostName.trim();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: LiveStoriesStrip._itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: LiveStoriesStrip._avatarSize,
              height: LiveStoriesStrip._avatarSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.liveGradient,
                      border: selected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: SafeNetworkAvatar(
                        imageUrl: live.hostAvatar ?? live.thumbnailUrl,
                        radius: (LiveStoriesStrip._avatarSize / 2) - 7,
                        fallbackText: name,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: const Icon(
                        Icons.equalizer,
                        color: Colors.white,
                        size: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textPrimary.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
