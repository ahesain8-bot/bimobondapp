import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:flutter/material.dart';

class VideoPostActionButton extends StatelessWidget {
  const VideoPostActionButton({
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
    this.onLongPress,
    this.iconWidget,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: VideoPostLayoutConstants.actionHitWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: VideoPostLayoutConstants.actionIconSize + 2,
              child: Center(
                child: iconWidget ??
                    Icon(
                      icon,
                      color: color,
                      size: VideoPostLayoutConstants.actionIconSize,
                      shadows: VideoPostLayoutConstants.actionTextShadow,
                    ),
              ),
            ),
            if (label != null && label!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: VideoPostLayoutConstants.actionLabelSize,
                  fontWeight: FontWeight.w600,
                  shadows: VideoPostLayoutConstants.actionTextShadow,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
