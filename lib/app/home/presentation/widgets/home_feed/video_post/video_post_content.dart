import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_bottom_info.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_chrome.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_gradient_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_layout_constants.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_media_badge.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_side_actions.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

/// Full-screen stack: media carousel + chrome overlays for a feed post.
class VideoPostContent extends StatelessWidget {
  const VideoPostContent({
    required this.size,
    required this.bottom,
    required this.post,
    required this.displayMedia,
    required this.currentPage,
    required this.carouselController,
    required this.mediaItemBuilder,
    required this.onPageChanged,
    required this.feedItem,
    required this.repostQuote,
    required this.postForBottomInfo,
    required this.sideActions,
    required this.onMusicTap,
    this.feedTopBarClearance,
    this.pageController,
    this.pageIndex,
    this.chromeEntranceController,
    this.chromeActionsRise,
    this.chromeCaptionRise,
    this.chromeFade,
    super.key,
  });

  final Size size;
  final double bottom;
  final PostEntity post;
  final List<PostMediaEntity> displayMedia;
  final int currentPage;
  final CarouselSliderController carouselController;
  final ExtendedIndexedWidgetBuilder mediaItemBuilder;
  final void Function(int index) onPageChanged;
  final FeedItemEntity? feedItem;
  final String? repostQuote;
  final PostEntity postForBottomInfo;
  final VideoPostSideActions sideActions;
  final VoidCallback? onMusicTap;
  final double? feedTopBarClearance;
  final PageController? pageController;
  final int? pageIndex;
  final AnimationController? chromeEntranceController;
  final Animation<double>? chromeActionsRise;
  final Animation<double>? chromeCaptionRise;
  final Animation<double>? chromeFade;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height,
      width: size.width,
      color: Colors.black,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CarouselSlider.builder(
            carouselController: carouselController,
            itemCount: displayMedia.length,
            options: CarouselOptions(
              height: size.height,
              viewportFraction: 1.0,
              enableInfiniteScroll: false,
              scrollDirection: Axis.horizontal,
              scrollPhysics: displayMedia.length > 1
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (index, reason) => onPageChanged(index),
            ),
            itemBuilder: mediaItemBuilder,
          ),
          const VideoPostGradientOverlay(),
          if (displayMedia.length > 1)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (feedTopBarClearance ??
                      HomeLayoutConstants.feedTopTabsTopPadding),
              left: 0,
              right: 0,
              child: Center(
                child: VideoPostMediaCountBadge(
                  currentPage: currentPage,
                  total: displayMedia.length,
                ),
              ),
            ),
          Positioned(
            right: VideoPostLayoutConstants.actionColumnInset,
            bottom: bottom + 20,
            child: VideoPostTransitionDim(
              pageController: pageController,
              pageIndex: pageIndex,
              child: VideoPostRiseFade(
                controller: chromeEntranceController,
                rise: chromeActionsRise,
                fade: chromeFade,
                child: sideActions,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: VideoPostRiseFade(
              controller: chromeEntranceController,
              rise: chromeCaptionRise,
              fade: chromeFade,
              child: VideoPostBottomInfo(
                post: postForBottomInfo,
                feedItem: feedItem,
                repostQuote: repostQuote,
                currentPage: currentPage,
                mediaCount: displayMedia.length,
                onMusicTap: onMusicTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
