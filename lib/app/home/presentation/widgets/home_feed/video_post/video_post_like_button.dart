import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_action_button.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:flutter/material.dart';

class VideoPostLikeButton extends StatelessWidget {
  const VideoPostLikeButton({
    required this.isLiked,
    required this.label,
    required this.scaleAnimation,
    required this.onTap,
    super.key,
  });

  final bool isLiked;
  final String label;
  final Animation<double> scaleAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isLiked
        ? VideoPostLayoutConstants.tikTokLikeRed
        : Colors.white;
    return VideoPostActionButton(
      icon: Icons.favorite,
      label: label,
      color: color,
      onTap: onTap,
      iconWidget: ScaleTransition(
        scale: scaleAnimation,
        child: Icon(
          Icons.favorite,
          color: color,
          size: VideoPostLayoutConstants.actionIconSize,
          shadows: VideoPostLayoutConstants.actionTextShadow,
        ),
      ),
    );
  }
}
