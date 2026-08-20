import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/feed_author_follow_cache.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_delete_flow.dart';
import 'package:bimobondapp/app/home/presentation/widgets/comments/quick_comment_reactions.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/comment_sheet_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_options_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_quick_share_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_content.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_media_item.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post/video_post_side_actions.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/app/posts/domain/usecases/add_comment_usecase.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/posts/presentation/di/posts_injector.dart'
    as posts_di;
import 'package:bimobondapp/app/posts/presentation/utils/post_view_recorder.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/services/post_share_refresh_bus.dart';
import 'package:bimobondapp/core/constants/traffic_source.dart';
import 'package:bimobondapp/core/utils/app_media_cache_manager.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

part 'video_post/video_post_engagement_mixin.dart';
part 'video_post/video_post_sound_mixin.dart';

class VideoPostWidget extends StatefulWidget {
  final PostEntity post;
  final FeedItemEntity? feedItem;
  final double? bottomPadding;
  final double? mediaBottomInset;
  final BoxFit feedMediaFit;
  final bool isActive;

  /// When false, playback ignores [FeedPlaybackGate] (e.g. profile posts viewer).
  final bool respectFeedPlaybackGate;
  final bool openCommentsOnLoad;
  final String? highlightCommentId;

  /// Extra top offset for carousel badge when a feed top bar overlays the post.
  final double? feedTopBarClearance;

  /// TikTok-style slide-up + fade for actions/caption when opening from profile.
  final bool animateChromeEntrance;

  /// Vertical [PageController] used to dim interaction icons mid-swipe.
  final PageController? pageController;

  /// Index of this post in [pageController] (required when [pageController] is set).
  final int? pageIndex;

  /// Keeps the parent feed list in sync when like/comment/save changes locally.
  final FeedPostPatch? onFeedPostPatch;

  /// Discovery surface for `POST /posts/:id/view` — see [TrafficSource].
  final String trafficSource;

  const VideoPostWidget({
    super.key,
    required this.post,
    this.feedItem,
    this.bottomPadding,
    this.mediaBottomInset,
    this.feedMediaFit = BoxFit.contain,
    this.isActive = true,
    this.respectFeedPlaybackGate = true,
    this.openCommentsOnLoad = false,
    this.highlightCommentId,
    this.feedTopBarClearance,
    this.animateChromeEntrance = false,
    this.pageController,
    this.pageIndex,
    this.onFeedPostPatch,
    this.trafficSource = TrafficSource.forYou,
  });

  @override
  State<VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<VideoPostWidget>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        VideoPostSoundMixin,
        VideoPostEngagementMixin {
  int _currentPage = 0;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;
  AnimationController? _chromeEntranceController;
  Animation<double>? _chromeActionsRise;
  Animation<double>? _chromeCaptionRise;
  Animation<double>? _chromeFade;
  Animation<double>? _likeRise;
  Animation<double>? _commentRise;
  bool _chromeEntrancePlayed = false;
  bool _chromeEntranceScheduled = false;
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeStatusListener;
  final CarouselSliderController _carouselCtrl = CarouselSliderController();
  final Map<int, CustomVideoPlayerController> _videoPlayerControllers = {};
  final GlobalKey _commentActionKey = GlobalKey();
  final GlobalKey _shareActionKey = GlobalKey();

  @override
  int get soundCurrentPage => _currentPage;

  @override
  Map<int, CustomVideoPlayerController> get soundVideoControllers =>
      _videoPlayerControllers;

  @override
  bool get soundPlaybackActive => _playbackActive;

  @override
  List<PostMediaEntity> get soundDisplayMedia => _displayMedia;

  @override
  AnimationController get likeAnimController => _likeAnimController;

  @override
  GlobalKey get commentActionKey => _commentActionKey;

  @override
  GlobalKey get shareActionKey => _shareActionKey;

  @override
  bool get engagementPlaybackActive => _playbackActive;

  bool get _playbackActive =>
      widget.isActive &&
      FeedPlaybackGate.instance.playbackAllowed(
        respectFeedPlaybackGate: widget.respectFeedPlaybackGate,
      );

  List<PostMediaEntity> get _displayMedia {
    if (widget.post.media.isNotEmpty) return widget.post.media;
    final videoUrl = widget.post.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return [PostMediaEntity(url: videoUrl, mediaType: 'VIDEO', order: 0)];
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FeedPlaybackGate.instance.addListener(_onFeedPlaybackGateChanged);
    PostShareRefreshBus.instance.addListener(_onPostShared);
    initEngagementState();

    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _likeScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _likeAnimController, curve: Curves.easeInOut),
        );

    if (widget.animateChromeEntrance) {
      _setupChromeEntranceAnimation();
    }

    if (_playbackActive) {
      resolveFollowStatusIfNeeded();
      _startViewWatchTracking();
      unawaited(SoundAudioPreview.stop());
      unawaited(syncPostSoundPlayback());
    }

    if (widget.openCommentsOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showComments();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_playbackActive) {
        _startViewWatchTracking();
        unawaited(syncPostSoundPlayback());
      }
      return;
    }
    // Locked / backgrounded — flush watch duration and stop soundtrack.
    flushPostViewWithWatchDuration();
    unawaited(pausePostSound());
    unawaited(SoundAudioPreview.stop());
  }

  /// This post was just shared from the options sheet: move the counter.
  /// Falls back to a local bump when the server did not report a total.
  void _onPostShared() {
    final bus = PostShareRefreshBus.instance;
    if (bus.lastSharedPostId != widget.post.id || !mounted) return;
    setState(() => shareCount = bus.lastShareCount ?? shareCount + 1);
  }

  void _onFeedPlaybackGateChanged() {
    if (!_playbackActive) {
      _pauseViewWatchTracking();
      unawaited(pausePostSound());
    } else if (widget.isActive) {
      _startViewWatchTracking();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_playbackActive) return;
        unawaited(syncPostSoundPlayback());
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VideoPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id ||
        feedPostEngagementChanged(widget.post, oldWidget.post) ||
        widget.post != oldWidget.post ||
        widget.feedItem != oldWidget.feedItem) {
      syncEngagementFromPost();
    }

    if (widget.post.id != oldWidget.post.id) {
      final oldCampaign = oldWidget.post.isPromoted || oldWidget.post.isAd
          ? oldWidget.post.promotion?.id
          : null;
      flushPostViewWithWatchDuration(
        postId: oldWidget.post.id,
        trafficSource: oldWidget.trafficSource,
        campaignId: oldCampaign,
      );
      resetViewWatchSession();
      if (_playbackActive) {
        _startViewWatchTracking();
      }
    }

    if (_playbackActive && !oldWidget.isActive) {
      _playChromeEntranceNow();
      resolveFollowStatusIfNeeded();
      _startViewWatchTracking();
      unawaited(SoundAudioPreview.stop());
      unawaited(syncPostSoundPlayback());
    } else if (!widget.isActive && oldWidget.isActive) {
      flushPostViewWithWatchDuration();
      unawaited(stopPostSound());
    } else if (!_playbackActive && oldWidget.isActive && widget.isActive) {
      _pauseViewWatchTracking();
      unawaited(pausePostSound());
    } else if (_playbackActive &&
        (widget.post.id != oldWidget.post.id ||
            widget.post.sound != oldWidget.post.sound)) {
      resetPostSoundMuteState();
      unawaited(syncPostSoundPlayback());
    }
  }

  Widget _buildMediaItem(PostMediaEntity media, int index) {
    // Keep the player "active" while this page is visible. Do not tie this to
    // [FeedPlaybackGate] — comments/sheets pause via the gate inside
    // [CustomVideoPlayer]; flipping isActive would dispose and reload the video.
    final isActiveSlide = widget.isActive && _currentPage == index;
    final hasImageSound =
        widget.post.sound?.resolvedAudioUrl?.isNotEmpty ?? false;
    final videoController = _videoPlayerControllers.putIfAbsent(
      index,
      CustomVideoPlayerController.new,
    );

    return VideoPostMediaItem(
      media: media,
      index: index,
      post: widget.post,
      isActiveSlide: isActiveSlide,
      respectFeedPlaybackGate: widget.respectFeedPlaybackGate,
      videoController: videoController,
      isImagePlaybackActive: isPostPlaybackActive(),
      isImageMuted: isPostSoundUserMuted,
      onLongPress: showMoreOptions,
      onImageTap: isActiveSlide && hasImageSound
          ? () => unawaited(togglePostPlayback())
          : null,
      onImageMuteTap: isActiveSlide && hasImageSound
          ? togglePostSoundMute
          : null,
      onPlaybackChanged: hasImageSound
          ? onVideoPlaybackChangedFromPlayer
          : null,
      onSeekSync: hasImageSound ? onVideoSeekSync : null,
      onUserMuteChanged: hasImageSound ? onVideoUserMuteChanged : null,
      onSegmentEnd: hasImageSound
          ? () => unawaited(onPostSoundSegmentLoop())
          : null,
      onVideoDurationReady:
          hasImageSound && isActiveSlide && isSlideVideo(index)
          ? onVideoDurationReady
          : null,
      segmentPlaybackMax: hasImageSound ? segmentPlaybackMaxForPost() : null,
      mediaFit: widget.feedMediaFit,
      mediaHeight:
          widget.mediaBottomInset != null && widget.mediaBottomInset! > 0
          ? MediaQuery.sizeOf(context).height - widget.mediaBottomInset!
          : null,
    );
  }

  @override
  void dispose() {
    _cancelViewEligibleTimer();
    flushPostViewWithWatchDuration();
    WidgetsBinding.instance.removeObserver(this);
    FeedPlaybackGate.instance.removeListener(_onFeedPlaybackGateChanged);
    PostShareRefreshBus.instance.removeListener(_onPostShared);
    _detachRouteListener();
    unawaited(stopPostSound());
    _chromeEntranceController?.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animateChromeEntrance) {
      _scheduleChromeAfterRoute();
    }
  }

  void _setupChromeEntranceAnimation() {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _chromeEntranceController = controller;

    _chromeActionsRise = Tween<double>(begin: 260, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _likeRise = Tween<double>(begin: 90, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.08, 0.88, curve: Curves.easeOutCubic),
      ),
    );
    _commentRise = Tween<double>(begin: 110, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.16, 0.95, curve: Curves.easeOutCubic),
      ),
    );
    _chromeCaptionRise = Tween<double>(begin: 140, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _chromeFade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
  }

  void _detachRouteListener() {
    final anim = _routeAnimation;
    final listener = _routeStatusListener;
    if (anim != null && listener != null) {
      anim.removeStatusListener(listener);
    }
    _routeAnimation = null;
    _routeStatusListener = null;
  }

  void _scheduleChromeAfterRoute() {
    if (!widget.animateChromeEntrance || _chromeEntrancePlayed) return;
    if (!widget.isActive) return;
    if (_chromeEntranceController == null) return;

    final routeAnim = ModalRoute.of(context)?.animation;

    void play() {
      if (!mounted || _chromeEntrancePlayed || !widget.isActive) return;
      _chromeEntrancePlayed = true;
      _detachRouteListener();
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (!mounted) return;
        _chromeEntranceController?.forward(from: 0);
      });
    }

    if (routeAnim == null || routeAnim.status == AnimationStatus.completed) {
      if (_chromeEntranceScheduled) return;
      _chromeEntranceScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 280), play);
      });
      return;
    }

    if (_routeAnimation == routeAnim && _routeStatusListener != null) return;

    _detachRouteListener();
    _chromeEntranceScheduled = true;
    _routeAnimation = routeAnim;
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) play();
    }

    _routeStatusListener = listener;
    routeAnim.addStatusListener(listener);
  }

  void _playChromeEntranceNow() {
    if (!widget.animateChromeEntrance || _chromeEntrancePlayed) return;
    if (!widget.isActive) return;
    final controller = _chromeEntranceController;
    if (controller == null) return;
    _chromeEntrancePlayed = true;
    _detachRouteListener();
    controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottom = widget.bottomPadding ?? 30.0;
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;

    final canOpenSound = post.sound != null && post.sound!.id.isNotEmpty;
    VoidCallback? musicTap;
    if (canOpenSound) {
      musicTap = () => openPostSound(post);
    } else if (canTogglePlayback) {
      musicTap = () => unawaited(togglePostPlayback());
    }

    return BlocListener<PostsBloc, PostsState>(
      listenWhen: (previous, current) {
        if (current is DeletePostSuccess && current.postId == post.id) {
          return true;
        }
        if (current is RepostPostSuccess && current.postId == post.id) {
          return true;
        }
        if (current is PostsFailure && pendingRepostToggle) {
          return true;
        }
        return false;
      },
      listener: (context, state) {
        if (state is DeletePostSuccess && state.postId == post.id) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.postDeletedSuccessfully)));
          if (context.canPop()) context.pop();
          return;
        }

        if (state is RepostPostSuccess && state.postId == post.id) {
          setState(() {
            isReposted = state.isReposted;
            pendingRepostToggle = false;
            syncRecentRepostersWithState();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.isReposted ? l10n.repostSuccess : l10n.repostRemoved,
              ),
            ),
          );
          return;
        }

        if (state is PostsFailure && pendingRepostToggle) {
          rollbackRepostToggle();
          PopupDialogs.showErrorDialog(context, state.message);
        }
      },
      child: VideoPostContent(
        size: size,
        bottom: bottom,
        mediaBottomInset: widget.mediaBottomInset ?? 0,
        post: post,
        displayMedia: _displayMedia,
        currentPage: _currentPage,
        carouselController: _carouselCtrl,
        mediaItemBuilder: (context, index, _) =>
            _buildMediaItem(_displayMedia[index], index),
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          if (widget.isActive) {
            FeedVideoProgressScope.maybeOf(context)?.reset();
          }
          unawaited(syncPostSoundPlayback());
        },
        feedItem: widget.feedItem,
        repostQuote: repostQuote,
        postForBottomInfo: postWithLocalRepostState(post),
        feedTopBarClearance: widget.feedTopBarClearance,
        pageController: widget.pageController,
        pageIndex: widget.pageIndex,
        chromeEntranceController: _chromeEntranceController,
        chromeActionsRise: _chromeActionsRise,
        chromeCaptionRise: _chromeCaptionRise,
        chromeFade: _chromeFade,
        onMusicTap: musicTap,
        sideActions: VideoPostSideActions(
          soundCoverUrl: post.sound?.resolvedCoverUrl,
          avatarUrl: post.user?.avatarUrl,
          username: post.user?.username,
          fullName: post.user?.fullName,
          userId: postAuthorUserId(),
          isFollowing: isFollowing,
          isFollowLoading: isFollowLoading,
          showFollowBadge: !isPostOwner() && followStatusResolved && !isFollowing,
          isLiked: isLiked,
          likeLabel: formatCompactCount(likeCount),
          likeScaleAnimation: _likeScaleAnim,
          commentLabel: formatCompactCount(commentCount),
          isSaved: isSaved,
          saveLabel: formatCompactCount(saveCount),
          shareLabel: formatCompactCount(shareCount),
          commentActionKey: _commentActionKey,
          shareActionKey: _shareActionKey,
          onAvatarTap: openAuthorProfile,
          onFollow: () => unawaited(handleFollow()),
          onLike: handleLike,
          onComment: showComments,
          onCommentLongPress: () => unawaited(showQuickCommentReactions()),
          onSave: handleSave,
          onShare: showMoreOptions,
          onShareLongPress: showQuickShare,
          onMusicTap: musicTap,
          likeRise: _likeRise,
          commentRise: _commentRise,
          engagementController: _chromeEntranceController,
        ),
      ),
    );
  }
}
