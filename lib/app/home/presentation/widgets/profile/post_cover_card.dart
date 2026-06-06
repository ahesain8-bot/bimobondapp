import 'package:bimobondapp/app/chats/domain/entities/shared_post_snapshot.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/live_details_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_grid_video_background.dart';
import 'package:bimobondapp/core/widgets/video_post_preview_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Post/story cover matching [ProfileGridTile] on the profile grid.
class PostCoverCard extends StatelessWidget {
  const PostCoverCard({
    required this.post,
    this.tabIndex = 0,
    this.theme,
    super.key,
  }) : snapshot = null,
       sharedStoryUi = null;

  const PostCoverCard.fromSnapshot({
    required this.snapshot,
    this.tabIndex = 0,
    this.theme,
    super.key,
  }) : post = null,
       sharedStoryUi = null;

  const PostCoverCard.fromSharedStoryUi({
    required this.sharedStoryUi,
    this.tabIndex = 0,
    this.theme,
    super.key,
  }) : post = null,
       snapshot = null;

  final PostEntity? post;
  final SharedPostSnapshot? snapshot;
  final Map<String, dynamic>? sharedStoryUi;
  final int tabIndex;
  final ThemeData? theme;

  String get _type {
    if (post != null) return post!.type;
    if (snapshot != null) return snapshot!.type;
    return sharedStoryUi?['type']?.toString() ?? 'IMAGE';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTheme = theme ?? Theme.of(context);
    final imageUrl = _resolveImageUrl();
    final isVideo = _isVideoPost();
    final isAuction = _isAuctionPost;
    final videoUrl = _resolveVideoUrl();
    final placeholderColor = resolvedTheme.dividerColor.withValues(
      alpha: resolvedTheme.brightness == Brightness.dark ? 0.12 : 0.06,
    );

    final posterUrl = _resolveVideoPosterUrl() ?? imageUrl;

    return ColoredBox(
      color: isVideo && posterUrl == null ? Colors.black : placeholderColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo && videoUrl != null && videoUrl.isNotEmpty)
            ProfileGridVideoBackground(videoUrl: videoUrl, posterUrl: posterUrl)
          else if (isVideo && posterUrl != null && posterUrl.isNotEmpty)
            SafeNetworkImage(
              imageUrl: posterUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else if (isVideo)
            const VideoPostPreviewPlaceholder(
              iconSize: ProfileLayoutConstants.gridPlaceholderIconSize,
            )
          else if (imageUrl != null &&
              imageUrl.isNotEmpty &&
              isValidNetworkImageUrl(imageUrl))
            SafeNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorIcon: isAuction
                  ? Icons.gavel_outlined
                  : Icons.image_outlined,
            )
          else
            _placeholderIcon(resolvedTheme, isVideo, isAuction),
          if (isVideo &&
              ((videoUrl != null && videoUrl.isNotEmpty) ||
                  (posterUrl != null && posterUrl.isNotEmpty)))
            const _ProfileVideoPlayIcon(),
        ],
      ),
    );
  }

  String? _resolveVideoUrl() {
    if (post != null) return MediaUtils.resolveVideoUrl(post!);
    return null;
  }

  String? _resolveVideoPosterUrl() {
    if (post != null) return MediaUtils.resolveVideoPosterUrl(post!);
    if (snapshot != null) {
      final thumb = snapshot!.thumbnailUrl;
      if (thumb != null && MediaUtils.isLikelyImageUrl(thumb)) {
        return MediaUtils.resolveAbsoluteUrl(thumb);
      }
    }
    return null;
  }

  String? _resolveImageUrl() {
    if (post != null) {
      if (post!.thumbnailUrl != null &&
          MediaUtils.isImage(post!.thumbnailUrl!)) {
        return post!.thumbnailUrl;
      }
      if (post!.media.isNotEmpty) {
        final first = post!.media.first;
        if (MediaUtils.isImage(first.url, mediaType: first.mediaType)) {
          return first.url;
        }
      }
      return null;
    }

    if (snapshot != null) {
      final thumb = snapshot!.thumbnailUrl;
      if (thumb != null && MediaUtils.isImage(thumb)) return thumb;
      final media = snapshot!.mediaUrl;
      if (media != null && MediaUtils.isImage(media)) return media;
      return null;
    }

    final ui = sharedStoryUi;
    if (ui != null) {
      final thumb = ui['thumbnailUrl']?.toString();
      if (thumb != null && MediaUtils.isImage(thumb)) return thumb;
      final image = ui['imageUrl']?.toString();
      if (image != null && image.isNotEmpty && _type.toUpperCase() != 'VIDEO') {
        return image;
      }
    }
    return null;
  }

  bool _isVideoPost() {
    if (_type.toUpperCase() == 'VIDEO') return true;
    if (post != null) {
      return post!.media.any(
        (m) => MediaUtils.isVideo(m.url, mediaType: m.mediaType),
      );
    }
    return false;
  }

  bool get _isAuctionPost => post?.isAuctionable ?? false;

  Widget _placeholderIcon(ThemeData theme, bool isVideo, bool isAuction) {
    final IconData icon;
    final Color color;

    if (tabIndex == 1) {
      icon = LucideIcons.heart;
      color = theme.colorScheme.primary.withValues(alpha: 0.35);
    } else if (tabIndex == 2) {
      icon = LucideIcons.bookmark;
      color = theme.colorScheme.secondary.withValues(alpha: 0.35);
    } else if (isAuction) {
      icon = LucideIcons.gavel;
      color = LiveDetailsLayoutConstants.giftCommentGold.withValues(
        alpha: 0.65,
      );
    } else {
      icon = isVideo ? Icons.play_arrow_rounded : Icons.image_outlined;
      color = theme.colorScheme.onSurface.withValues(alpha: 0.3);
    }

    return Center(
      child: Icon(
        icon,
        size: ProfileLayoutConstants.gridPlaceholderIconSize,
        color: color,
      ),
    );
  }
}

class _ProfileVideoPlayIcon extends StatelessWidget {
  const _ProfileVideoPlayIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        LucideIcons.play,
        size: ProfileLayoutConstants.gridPlaceholderIconSize,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}
