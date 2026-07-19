import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_action_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_like_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_music_disc.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_profile_avatar.dart';
import 'package:bimobondapp/core/utils/app_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostSideActions extends StatelessWidget {
  const VideoPostSideActions({
    required this.avatarUrl,
    required this.username,
    required this.fullName,
    required this.userId,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.showFollowBadge,
    required this.isLiked,
    required this.likeLabel,
    required this.likeScaleAnimation,
    required this.commentLabel,
    required this.isSaved,
    required this.saveLabel,
    required this.musicRotation,
    required this.commentActionKey,
    required this.shareActionKey,
    required this.onAvatarTap,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onCommentLongPress,
    required this.onSave,
    required this.onShare,
    required this.onShareLongPress,
    this.onMusicTap,
    this.likeRise,
    this.commentRise,
    this.engagementController,
    super.key,
  });

  final String? avatarUrl;
  final String? username;
  final String? fullName;
  final String? userId;
  final bool isFollowing;
  final bool isFollowLoading;
  final bool showFollowBadge;
  final bool isLiked;
  final String likeLabel;
  final Animation<double> likeScaleAnimation;
  final String commentLabel;
  final bool isSaved;
  final String saveLabel;
  final Animation<double> musicRotation;
  final GlobalKey commentActionKey;
  final GlobalKey shareActionKey;
  final VoidCallback onAvatarTap;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onCommentLongPress;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onShareLongPress;
  final VoidCallback? onMusicTap;
  final Animation<double>? likeRise;
  final Animation<double>? commentRise;
  final AnimationController? engagementController;

  Widget _wrapEngagementRise(Animation<double>? rise, Widget child) {
    final controller = engagementController;
    if (controller == null || rise == null) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(offset: Offset(0, rise.value), child: child);
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        VideoPostProfileAvatar(
          avatarUrl: avatarUrl,
          username: username,
          fullName: fullName,
          userId: userId,
          isFollowing: isFollowing,
          isFollowLoading: isFollowLoading,
          showFollowBadge: showFollowBadge,
          onTap: onAvatarTap,
          onFollow: onFollow,
        ),
        const SizedBox(height: 22),
        _wrapEngagementRise(
          likeRise,
          VideoPostLikeButton(
            isLiked: isLiked,
            label: likeLabel,
            scaleAnimation: likeScaleAnimation,
            onTap: onLike,
          ),
        ),
        const SizedBox(height: VideoPostLayoutConstants.actionSpacing),
        _wrapEngagementRise(
          commentRise,
          KeyedSubtree(
            key: commentActionKey,
            child: VideoPostActionButton(
              icon: LucideIcons.messageCircleMore400,
              label: commentLabel,
              color: Colors.white,
              onTap: onComment,
              onLongPress: onCommentLongPress,
              iconWidget: SvgPicture.asset(
                AppAssets.commentIcon,
                width: VideoPostLayoutConstants.actionIconSize,
                height: VideoPostLayoutConstants.actionIconSize,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: VideoPostLayoutConstants.actionSpacing),
        VideoPostActionButton(
          icon: Icons.bookmark,
          label: saveLabel,
          color: isSaved
              ? VideoPostLayoutConstants.tikTokSaveYellow
              : Colors.white,
          onTap: onSave,
        ),
        const SizedBox(height: VideoPostLayoutConstants.actionSpacing),
        KeyedSubtree(
          key: shareActionKey,
          child: VideoPostActionButton(
            icon: LucideIcons.forward400,
            color: Colors.white,
            onTap: onShare,
            onLongPress: onShareLongPress,
            iconWidget: SvgPicture.asset(
              AppAssets.shareArrowIcon,
              width: VideoPostLayoutConstants.actionIconSize,
              height: VideoPostLayoutConstants.actionIconSize,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        const SizedBox(height: VideoPostLayoutConstants.actionSpacing),
        VideoPostMusicDisc(
          rotation: musicRotation,
          onTap: onMusicTap,
        ),
      ],
    );
  }
}
