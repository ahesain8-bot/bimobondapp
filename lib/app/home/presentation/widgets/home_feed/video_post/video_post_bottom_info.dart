import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_repost_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_caption_tags.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_hashtag_chips.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_location_chip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_music_label.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_page_dots.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class VideoPostBottomInfo extends StatelessWidget {
  const VideoPostBottomInfo({
    required this.post,
    required this.feedItem,
    required this.repostQuote,
    required this.currentPage,
    required this.mediaCount,
    this.onMusicTap,
    super.key,
  });

  final PostEntity post;
  final FeedItemEntity? feedItem;
  final String? repostQuote;
  final int currentPage;
  final int mediaCount;
  final VoidCallback? onMusicTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mediaCount > 1) ...[
          IgnorePointer(
            child: VideoPostPageDots(
              currentPage: currentPage,
              total: mediaCount,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.only(
            left: VideoPostLayoutConstants.contentEdgeInset,
            right: VideoPostLayoutConstants.contentActionSidePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FeedRepostBanner(
                post: post,
                feedItem: feedItem,
                repostQuote: repostQuote,
              ),
              if (post.location != null && post.location!.hasDisplayLabel)
                PostLocationChip(location: post.location!),
              if (post.isPromoted || post.isAd) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        size: 12,
                        color: Color(0xFFFF8C42),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.promotion?.label ??
                            AppLocalizations.of(context)!.promotedBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if ((post.description ?? '').isNotEmpty)
                PostCaptionTags(post: post)
              else if (post.hashtags.isNotEmpty)
                PostHashtagChips(tags: post.hashtags),
              const SizedBox(height: 10),
              VideoPostMusicLabel(
                soundName: post.sound?.name,
                onTap: onMusicTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
