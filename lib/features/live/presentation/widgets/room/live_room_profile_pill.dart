import 'package:flutter/material.dart';

import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../domain/entities/live_host.dart';

/// Host profile capsule — TikTok style:
/// `[avatar · name · ♥ hearts]  [peach ♥ likes]`
class LiveRoomProfilePill extends StatelessWidget {
  const LiveRoomProfilePill({
    super.key,
    required this.host,
    this.followerCount = 0,
    this.likeCount = 0,
  });

  final LiveHost host;

  /// Profile heart total (`hostHeartCount`) under the name.
  final int followerCount;

  /// Live session like taps — shown in the nested light chip.
  final int likeCount;

  static const Color _outerFill = Color(0x99202028);
  static const Color _likesChipFill = Color(0xE8F0E8F5);
  static const Color _likesChipText = Color(0xFF5C2D6B);
  static const Color _peachHeart = Color(0xFFFF8A65);

  @override
  Widget build(BuildContext context) {
    final hostName = host.displayName.trim();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 40,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.58,
        ),
        padding: const EdgeInsets.fromLTRB(3, 3, 4, 3),
        decoration: BoxDecoration(
          color: _outerFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HostAvatar(host: host),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.roomHostName.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 9,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$followerCount',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _LikesChip(likeCount: likeCount),
          ],
        ),
      ),
    );
  }
}

class _LikesChip extends StatelessWidget {
  const _LikesChip({required this.likeCount});

  final int likeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: LiveRoomProfilePill._likesChipFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite,
            size: 14,
            color: LiveRoomProfilePill._peachHeart,
          ),
          const SizedBox(width: 4),
          Text(
            '$likeCount',
            style: const TextStyle(
              color: LiveRoomProfilePill._likesChipText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.host});

  final LiveHost host;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.hostAvatarStart, AppColors.hostAvatarEnd],
        ),
        image: host.avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(host.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }
}

/// Standalone likes chip (legacy); prefer the nested chip inside
/// [LiveRoomProfilePill].
class LiveRoomLikesPill extends StatelessWidget {
  const LiveRoomLikesPill({super.key, required this.likeCount});

  final int likeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xE8F0E8F5),
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite, size: 14, color: Color(0xFFFF8A65)),
          const SizedBox(width: 4),
          Text(
            '$likeCount',
            style: AppTextStyles.roomCounter.copyWith(
              fontSize: 12,
              color: const Color(0xFF5C2D6B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
