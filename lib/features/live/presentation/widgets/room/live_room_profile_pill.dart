import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/utils/app_assets.dart';
import '../../../../../core/utils/app_colors.dart';
import '../../../../../core/utils/app_sizes.dart';
import '../../../../../core/utils/app_text_styles.dart';
import '../../../domain/entities/live_host.dart';
import 'live_room_pill.dart';

/// Host profile: avatar + name + mini counter under the name.
class LiveRoomProfilePill extends StatelessWidget {
  const LiveRoomProfilePill({
    super.key,
    required this.host,
    this.followerCount = 0,
  });

  final LiveHost host;
  final int followerCount;

  @override
  Widget build(BuildContext context) {
    return LiveRoomPill(
      height: 40,
      padding: const EdgeInsetsDirectional.only(start: 3, end: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HostAvatar(host: host),
          const SizedBox(width: 6),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 86),
                child: Text(
                  host.displayName,
                  style: AppTextStyles.roomHostName.copyWith(
                    fontSize: 12,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    AppAssets.roomHeart,
                    width: 10,
                    height: 9,
                    colorFilter: const ColorFilter.mode(
                      Colors.white70,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$followerCount',
                    style: AppTextStyles.roomCounter.copyWith(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
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
      width: AppSizes.roomAvatar,
      height: AppSizes.roomAvatar,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 0.8),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.hostAvatarStart,
            AppColors.hostAvatarEnd,
          ],
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

/// Orange heart likes chip that sits beside the profile pill.
class LiveRoomLikesPill extends StatelessWidget {
  const LiveRoomLikesPill({
    super.key,
    required this.likeCount,
  });

  final int likeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.overlayPill,
        borderRadius: BorderRadius.circular(AppSizes.radiusPill),
        border: Border.all(
          color: AppColors.heartOrange.withValues(alpha: 0.85),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.roomHeart,
            width: 13,
            height: 12,
          ),
          const SizedBox(width: 4),
          Text(
            '$likeCount',
            style: AppTextStyles.roomCounter.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
