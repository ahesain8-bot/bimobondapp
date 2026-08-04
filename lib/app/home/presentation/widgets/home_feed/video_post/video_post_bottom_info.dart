import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_repost_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_caption_tags.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_hashtag_chips.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_links_chip.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_music_label.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_page_dots.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
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

  Future<void> _openAuthor(BuildContext context) async {
    final user = post.user;
    final id = user?.id.trim() ?? '';
    if (id.isEmpty) return;
    await openUserActiveStoriesOrProfile(
      context,
      userId: id,
      username: user?.username,
      fullName: user?.fullName,
      avatarUrl: user?.avatarUrl,
      isFollowing: user?.isFollowing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = post.user;
    final fullName = user?.fullName?.trim();
    final username = user?.username.trim();
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (username != null && username.isNotEmpty ? username : null);
    final hasDisplayName = displayName != null;

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
          const SizedBox(height: 12),
        ],
        // Keep name / caption / sound pinned to the physical left (LTR),
        // even when the app locale is RTL.
        Align(
          alignment: Alignment.centerLeft,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.only(
                left: VideoPostLayoutConstants.contentEdgeInset,
                right: VideoPostLayoutConstants.contentActionSidePadding,
                bottom: 0,
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
                  PostLinksChip(post: post),
                  if (hasDisplayName) ...[
                    GestureDetector(
                      onTap: () => _openAuthor(context),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if ((post.description ?? '').isNotEmpty)
                    PostCaptionTags(post: post)
                  else if (post.hashtags.isNotEmpty)
                    PostHashtagChips(tags: post.hashtags),
                  const SizedBox(height: 4),
                  VideoPostMusicLabel(
                    soundName: post.sound?.name,
                    soundAuthor: post.sound?.author,
                    soundId: post.sound?.id,
                    postUsername: displayName ?? username,
                    onTap: onMusicTap,
                  ),
                  if (post.isPromoted || post.isAd) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.flame,
                            size: 12,
                            color: Color(0xFFFF8C42),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            post.promotion?.label ?? l10n.promotedBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
