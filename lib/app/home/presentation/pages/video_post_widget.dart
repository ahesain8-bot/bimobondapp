import 'dart:async';
import 'dart:ui';

import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_repost_overlay.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/repost_entity.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/posts/presentation/utils/post_view_recorder.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/comment_sheet_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/repost_sheet.dart';
import 'package:bimobondapp/app/sounds/presentation/utils/sound_audio_preview.dart';
import 'package:bimobondapp/app/social/domain/usecases/social_user_list_usecases.dart';
import 'package:bimobondapp/app/social/domain/usecases/toggle_follow_usecase.dart';
import 'package:bimobondapp/app/social/presentation/di/social_injector.dart'
    as social_di;
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/core/navigation/hashtag_navigation.dart';
import 'package:bimobondapp/core/navigation/sound_navigation.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/utils/tag_parser.dart';
import 'package:bimobondapp/core/widgets/tagged_text.dart';
import 'package:bimobondapp/core/services/feed_playback_gate.dart';
import 'package:bimobondapp/core/widgets/blurred_icon_badge.dart';
import 'package:bimobondapp/core/widgets/custom_video_player.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/core/utils/format_count.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/post_options_sheet.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

class VideoPostWidget extends StatefulWidget {
  final PostEntity post;
  final FeedItemEntity? feedItem;
  final double? bottomPadding;
  final bool isActive;
  /// When false, playback ignores [FeedPlaybackGate] (e.g. profile posts viewer).
  final bool respectFeedPlaybackGate;
  final bool openCommentsOnLoad;
  final String? highlightCommentId;
  /// Extra top offset for carousel badge when a feed top bar overlays the post.
  final double? feedTopBarClearance;

  const VideoPostWidget({
    super.key,
    required this.post,
    this.feedItem,
    this.bottomPadding,
    this.isActive = true,
    this.respectFeedPlaybackGate = true,
    this.openCommentsOnLoad = false,
    this.highlightCommentId,
    this.feedTopBarClearance,
  });

  @override
  State<VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<VideoPostWidget>
    with TickerProviderStateMixin {
  static const double _actionIconSize = 35;
  static const double _actionLabelSize = 12;
  static const double _actionSpacing = 20;
  static const double _actionHitWidth = 48;
  static const double _actionColumnInset = 8;
  static const double _contentActionGap = 12;
  static const double _contentActionSidePadding =
      _actionColumnInset + _actionHitWidth + _contentActionGap;
  static const double _contentEdgeInset = 16;
  static const double _profileAvatarRadius = 24;
  static const double _musicDiscSize = 40;
  static const Color _tikTokLikeRed = Color(0xFFFE2C55);
  static const Color _tikTokSaveYellow = Color(0xFFFACC15);
  static const List<Shadow> _actionTextShadow = [
    Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1)),
  ];

  int _currentPage = 0;
  late AnimationController _musicController;
  late AnimationController _likeAnimController;
  late Animation<double> _likeScaleAnim;
  final CarouselSliderController _carouselCtrl = CarouselSliderController();
  final Map<int, CustomVideoPlayerController> _videoPlayerControllers = {};
  VideoPlayerController? _postSoundController;
  VoidCallback? _postSoundListener;

  // Local state for optimistic UI
  late bool _isLiked;
  late int _likeCount;
  late bool _isSaved;
  late int _saveCount;
  late bool _isReposted;
  late int _repostCount;
  late List<RepostUserEntity> _recentReposters;
  String? _repostQuote;
  bool _pendingRepostToggle = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _followStatusResolved = false;

  bool get _playbackActive =>
      widget.isActive &&
      (!widget.respectFeedPlaybackGate || FeedPlaybackGate.instance.allowed);

  @override
  void initState() {
    super.initState();
    if (widget.respectFeedPlaybackGate) {
      FeedPlaybackGate.instance.addListener(_onFeedPlaybackGateChanged);
    }
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _isSaved = widget.post.isSaved;
    _saveCount = widget.post.saveCount;
    _isReposted = widget.post.isReposted;
    _repostCount = widget.post.repostCount;
    _recentReposters = List<RepostUserEntity>.from(widget.post.recentReposters);
    _repostQuote = _initialRepostQuote();
    _isFollowing = widget.post.user?.isFollowing ?? false;
    _followStatusResolved = widget.post.user?.isFollowing != null;

    _musicController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

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

    if (_playbackActive) {
      _resolveFollowStatusIfNeeded();
      _recordViewIfNeeded();
      unawaited(SoundAudioPreview.stop());
      unawaited(
        _syncPostSoundPlayback().then((_) {
          if (mounted) _syncMusicDiscAnimation();
        }),
      );
    }

    if (widget.openCommentsOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showComments();
      });
    }
  }

  void _onFeedPlaybackGateChanged() {
    if (!_playbackActive) {
      unawaited(_pausePostSound());
      _syncMusicDiscAnimation();
    } else if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_playbackActive) return;
        unawaited(
          _syncPostSoundPlayback().then((_) {
            if (mounted) _syncMusicDiscAnimation();
          }),
        );
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VideoPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id ||
        widget.post != oldWidget.post ||
        widget.feedItem != oldWidget.feedItem) {
      _isLiked = widget.post.isLiked;
      _likeCount = widget.post.likeCount;
      _isSaved = widget.post.isSaved;
      _saveCount = widget.post.saveCount;
      _isReposted = widget.post.isReposted;
      _repostCount = widget.post.repostCount;
      _recentReposters = List<RepostUserEntity>.from(
        widget.post.recentReposters,
      );
      _repostQuote = _initialRepostQuote();
      _isFollowing = widget.post.user?.isFollowing ?? false;
      _followStatusResolved = widget.post.user?.isFollowing != null;
      _isFollowLoading = false;
    }

    if (_playbackActive && !oldWidget.isActive) {
      _resolveFollowStatusIfNeeded();
      _recordViewIfNeeded();
      unawaited(SoundAudioPreview.stop());
      unawaited(
        _syncPostSoundPlayback().then((_) {
          if (mounted) _syncMusicDiscAnimation();
        }),
      );
    } else if (!widget.isActive && oldWidget.isActive) {
      unawaited(_stopPostSound());
      _syncMusicDiscAnimation();
    } else if (widget.respectFeedPlaybackGate &&
        !FeedPlaybackGate.instance.allowed &&
        oldWidget.isActive &&
        widget.isActive) {
      unawaited(_pausePostSound());
      _syncMusicDiscAnimation();
    } else if (_playbackActive &&
        (widget.post.id != oldWidget.post.id ||
            widget.post.sound != oldWidget.post.sound)) {
      unawaited(_syncPostSoundPlayback());
    }
  }

  void _recordViewIfNeeded() {
    if (!_playbackActive || widget.post.isStory) return;
    PostViewRecorder.recordIfNeeded(
      postId: widget.post.id,
      isOwner: _isPostOwner(),
    );
  }

  Future<void> _resolveFollowStatusIfNeeded() async {
    if (_followStatusResolved || _isPostOwner() || !mounted) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final authorId = _postAuthorUserId();
    if (authorId == null || authorId.isEmpty) return;

    final result = await social_di.sl<CheckIsFollowingUseCase>()(
      CheckIsFollowingParams(
        currentUserId: authState.user.id,
        targetUserId: authorId,
      ),
    );
    if (!mounted) return;

    result.fold((_) {}, (isFollowing) {
      setState(() {
        _isFollowing = isFollowing;
        _followStatusResolved = true;
      });
    });
  }

  Future<void> _handleFollow() async {
    if (_isPostOwner() || _isFollowing || _isFollowLoading) return;
    if (!_checkAuth()) return;

    final userId = _postAuthorUserId();
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _isFollowLoading = true;
      _isFollowing = true;
    });

    final result = await social_di.sl<ToggleFollowUseCase>()(
      ToggleFollowParams(userId),
    );
    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isFollowing = false;
          _isFollowLoading = false;
        });
        PopupDialogs.showErrorDialog(context, failure.message);
      },
      (_) {
        setState(() {
          _isFollowing = true;
          _isFollowLoading = false;
          _followStatusResolved = true;
        });
      },
    );
  }

  void _handleLike() {
    if (!_checkAuth()) return;
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likeCount++ : _likeCount--;
    });
    _likeAnimController.forward(from: 0);
    context.read<PostsBloc>().add(
      ToggleLikePostRequestedEvent(widget.post.id, liked: _isLiked),
    );
  }

  void _handleSave() {
    if (!_checkAuth()) return;
    setState(() {
      _isSaved = !_isSaved;
      _isSaved ? _saveCount++ : _saveCount--;
    });
    context.read<PostsBloc>().add(ToggleSavePostRequestedEvent(widget.post.id));
  }

  void _handleRepostTap() {
    if (!_checkAuth()) return;
    if (_isPostOwner()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.cannotRepostOwnPost),
        ),
      );
      return;
    }

    if (_isReposted) {
      _toggleRepost();
      return;
    }

    RepostSheet.show(
      context: context,
      onRepost: (quote) => _toggleRepost(quote: quote),
    );
  }

  String? _initialRepostQuote() {
    final fromFeed = widget.feedItem?.quote?.trim();
    if (fromFeed != null && fromFeed.isNotEmpty) return fromFeed;

    if (widget.post.isReposted) {
      for (final r in widget.post.recentReposters) {
        final q = r.quote?.trim();
        if (q != null && q.isNotEmpty) return q;
      }
    }
    return null;
  }

  RepostUserEntity? _currentUserAsReposter() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return null;
    final user = authState.user;
    return RepostUserEntity(
      id: user.id,
      username: user.username ?? 'user',
      fullName: user.fullName,
      avatarUrl: user.avatarUrl,
      isVerified: user.isVerified ?? false,
      repostedAt: DateTime.now(),
    );
  }

  void _syncRecentRepostersWithState() {
    final me = _currentUserAsReposter();
    if (me == null) return;
    _recentReposters.removeWhere((r) => r.id == me.id);
    if (_isReposted) {
      _recentReposters.insert(
        0,
        RepostUserEntity(
          id: me.id,
          username: me.username,
          fullName: me.fullName,
          avatarUrl: me.avatarUrl,
          isVerified: me.isVerified,
          repostedAt: me.repostedAt,
          quote: _repostQuote,
        ),
      );
    }
  }

  void _toggleRepost({String? quote}) {
    final wasReposted = _isReposted;
    final trimmedQuote = quote?.trim();
    setState(() {
      _pendingRepostToggle = true;
      _isReposted = !wasReposted;
      wasReposted ? _repostCount-- : _repostCount++;
      if (!wasReposted) {
        _repostQuote = trimmedQuote != null && trimmedQuote.isNotEmpty
            ? trimmedQuote
            : null;
      } else {
        _repostQuote = null;
      }
      _syncRecentRepostersWithState();
    });
    context.read<PostsBloc>().add(
      ToggleRepostPostRequestedEvent(widget.post.id, quote: quote),
    );
  }

  void _rollbackRepostToggle() {
    if (!_pendingRepostToggle) return;
    setState(() {
      _isReposted = !_isReposted;
      _isReposted ? _repostCount++ : _repostCount--;
      if (!_isReposted) {
        _repostQuote = _initialRepostQuote();
      }
      _syncRecentRepostersWithState();
      _pendingRepostToggle = false;
    });
  }

  PostEntity _postWithLocalRepostState(PostEntity post) {
    return post.copyWith(
      repostCount: _repostCount,
      isReposted: _isReposted,
      recentReposters: _recentReposters,
    );
  }

  void _showComments({int initialTabIndex = 1}) {
    final isOwner = _isPostOwner();
    CommentSheetWidget.show(
      context,
      postId: widget.post.id,
      postOwnerId: widget.post.userId,
      likeCount: _likeCount,
      commentCount: widget.post.commentCount,
      viewCount: widget.post.viewCount,
      isPostOwner: isOwner,
      initialTabIndex: isOwner ? initialTabIndex : 0,
    );
  }

  bool _isPostOwner() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return false;

    final ownerIds = {
      authState.user.id,
      if (authState.user.firebaseUid != null) authState.user.firebaseUid!,
    };
    final postOwnerIds = {
      widget.post.userId,
      if (widget.post.user != null) widget.post.user!.id,
    };
    return ownerIds.any(postOwnerIds.contains);
  }

  String? _postAuthorUserId() {
    final user = widget.post.user;
    if (user != null && user.id.isNotEmpty) return user.id;
    if (widget.post.userId.isNotEmpty) return widget.post.userId;
    return null;
  }

  Future<void> _openAuthorProfile() async {
    final userId = _postAuthorUserId();
    if (userId == null) return;

    final isFollowing = await openUserStoryOrProfile(
      context,
      userId: userId,
      username: widget.post.user?.username,
      fullName: widget.post.user?.username,
      avatarUrl: widget.post.user?.avatarUrl,
      isFollowing: _isFollowing,
    );
    if (!mounted || isFollowing == null) return;

    setState(() {
      _isFollowing = isFollowing;
      _followStatusResolved = true;
    });
  }

  void _showMoreOptions() {
    if (!_checkAuth()) return;

    PostOptionsSheet.show(
      context,
      post: widget.post,
      isOwner: _isPostOwner(),
      onEdit: _isPostOwner() ? _openEditPost : null,
      onPromote: _isPostOwner() && widget.post.canBePromoted
          ? () => context.pushFromFeed('promote_post', extra: widget.post)
          : null,
      onDelete: _isPostOwner() ? _confirmDeletePost : null,
      onRepost: _isPostOwner() ? null : _handleRepostTap,
      isReposted: _isReposted,
    );
  }

  Future<void> _openEditPost() async {
    if (!_checkAuth() || !_isPostOwner()) return;
    await context.pushFromFeed<PostEntity>('edit_post', extra: widget.post);
  }

  void _confirmDeletePost() {
    if (!_checkAuth() || !_isPostOwner()) return;
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.deletePostTitle,
      message: l10n.deletePostMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        context.read<PostsBloc>().add(DeletePostRequestedEvent(widget.post.id));
      },
    );
  }

  List<PostMediaEntity> get _displayMedia {
    if (widget.post.media.isNotEmpty) return widget.post.media;
    final videoUrl = widget.post.videoUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      return [PostMediaEntity(url: videoUrl, mediaType: 'VIDEO', order: 0)];
    }
    return [];
  }

  bool get _canTogglePlayback =>
      _isSlideVideo(_currentPage) ||
      (widget.post.sound?.resolvedAudioUrl?.isNotEmpty ?? false);

  bool _isPostPlaybackActive() {
    if (_isSlideVideo(_currentPage)) {
      return _videoPlayerControllers[_currentPage]?.isPlaying ?? false;
    }
    return _postSoundController?.value.isPlaying ?? false;
  }

  void _syncMusicDiscAnimation() {
    if (!_playbackActive || !_isPostPlaybackActive()) {
      if (_musicController.isAnimating) _musicController.stop();
      return;
    }
    if (!_musicController.isAnimating) _musicController.repeat();
  }

  Future<void> _togglePostPlayback() async {
    if (!_canTogglePlayback) return;

    if (_isSlideVideo(_currentPage)) {
      await _videoPlayerControllers[_currentPage]?.togglePlayback();
    } else {
      final controller = _postSoundController;
      if (controller != null && controller.value.isInitialized) {
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.setVolume(1);
          await controller.play();
        }
      } else {
        await _syncPostSoundPlayback();
      }
    }

    if (mounted) {
      _syncMusicDiscAnimation();
      setState(() {});
    }
  }

  bool _isSlideVideo(int index) {
    final media = _displayMedia;
    if (media.isEmpty) {
      final videoUrl = widget.post.videoUrl;
      return widget.post.type == 'VIDEO' ||
          (videoUrl != null && MediaUtils.isVideo(videoUrl));
    }
    if (index < 0 || index >= media.length) return false;
    final item = media[index];
    final url = MediaUtils.resolveAbsoluteUrl(item.url);
    return MediaUtils.isVideo(url, mediaType: item.mediaType) ||
        widget.post.type == 'VIDEO';
  }

  Future<void> _pausePostSound() async {
    final controller = _postSoundController;
    if (controller == null) return;
    try {
      if (!controller.value.isInitialized) return;
      await controller.pause();
    } catch (_) {}
    _syncMusicDiscAnimation();
  }

  Future<void> _stopPostSound() async {
    final controller = _postSoundController;
    final listener = _postSoundListener;
    _postSoundController = null;
    _postSoundListener = null;
    if (controller == null) return;
    if (listener != null) {
      controller.removeListener(listener);
    }
    try {
      await controller.pause();
      await controller.dispose();
    } catch (_) {}
    _syncMusicDiscAnimation();
  }

  Future<void> _syncPostSoundPlayback() async {
    if (!_playbackActive || _isSlideVideo(_currentPage)) {
      await _stopPostSound();
      return;
    }

    final audioUrl = widget.post.sound?.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      await _stopPostSound();
      return;
    }

    final existing = _postSoundController;
    if (existing != null &&
        existing.dataSource == audioUrl &&
        existing.value.isInitialized) {
      if (!existing.value.isPlaying) {
        await existing.setVolume(1);
        await existing.play();
      }
      return;
    }

    await _stopPostSound();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(audioUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    _postSoundController = controller;
    void onSoundPlaybackChanged() {
      if (!mounted) return;
      _syncMusicDiscAnimation();
      setState(() {});
    }

    _postSoundListener = onSoundPlaybackChanged;
    controller.addListener(onSoundPlaybackChanged);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (!mounted ||
          !_playbackActive ||
          _isSlideVideo(_currentPage) ||
          _postSoundController != controller) {
        await controller.dispose();
        return;
      }
      await controller.play();
      _syncMusicDiscAnimation();
    } catch (_) {
      await _stopPostSound();
    }
  }

  bool _checkAuth() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) return true;
    final l10n = AppLocalizations.of(context)!;
    PopupDialogs.showConfirmDialog(
      context,
      title: l10n.loginRequired,
      message: l10n.loginRequiredMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.login,
      onConfirm: () => context.pushNamed('login'),
    );
    return false;
  }

  Widget _buildMediaItem(PostMediaEntity media, int index) {
    final mediaUrl = MediaUtils.resolveAbsoluteUrl(media.url);
    final isVideo =
        MediaUtils.isVideo(mediaUrl, mediaType: media.mediaType) ||
        widget.post.type == 'VIDEO';
    final isActiveSlide = _playbackActive && _currentPage == index;
    final videoController = _videoPlayerControllers.putIfAbsent(
      index,
      CustomVideoPlayerController.new,
    );

    Widget child = isVideo
        ? CustomVideoPlayer(
            url: mediaUrl,
            posterUrl: MediaUtils.resolveVideoPosterUrl(widget.post),
            isActive: isActiveSlide,
            respectFeedPlaybackGate: widget.respectFeedPlaybackGate,
            controller: videoController,
            onPlaybackChanged: _syncMusicDiscAnimation,
          )
        : mediaUrl.isEmpty
        ? const Icon(LucideIcons.imageOff, size: 80, color: Colors.white24)
        : SafeNetworkImage(
            imageUrl: mediaUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorIcon: LucideIcons.imageOff,
          );

    if (!isVideo &&
        isActiveSlide &&
        (widget.post.sound?.resolvedAudioUrl?.isNotEmpty ?? false)) {
      final isPlaying = isActiveSlide && _isPostPlaybackActive();
      child = GestureDetector(
        onTap: () => unawaited(_togglePostPlayback()),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            child,
            if (isActiveSlide && !isPlaying)
              BlurredIconBadge(
                icon: LucideIcons.play,
                diameter: 88,
                iconSize: 44,
                iconColor: Colors.white.withValues(alpha: 0.85),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      key: ValueKey('${mediaUrl}_$index'),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Center(child: child),
    );
  }

  @override
  void dispose() {
    FeedPlaybackGate.instance.removeListener(_onFeedPlaybackGateChanged);
    unawaited(_stopPostSound());
    _musicController.dispose();
    _likeAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottom = widget.bottomPadding ?? 30.0;
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocListener<PostsBloc, PostsState>(
      listenWhen: (previous, current) {
        if (current is DeletePostSuccess && current.postId == post.id) {
          return true;
        }
        if (current is RepostPostSuccess && current.postId == post.id) {
          return true;
        }
        if (current is PostsFailure && _pendingRepostToggle) {
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
            _isReposted = state.isReposted;
            _pendingRepostToggle = false;
            _syncRecentRepostersWithState();
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

        if (state is PostsFailure && _pendingRepostToggle) {
          _rollbackRepostToggle();
          PopupDialogs.showErrorDialog(context, state.message);
        }
      },
      child: _buildPostContent(size, bottom, post, theme),
    );
  }

  Widget _buildPostContent(
    Size size,
    double bottom,
    PostEntity post,
    ThemeData theme,
  ) {
    final actionsOnRight = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      height: size.height,
      width: size.width,
      color: Colors.black,
      child: Stack(
        children: [
          // ── Media Carousel ───────────────────────────────────────────────
          CarouselSlider.builder(
            carouselController: _carouselCtrl,
            itemCount: _displayMedia.length,
            options: CarouselOptions(
              height: size.height,
              viewportFraction: 1.0,
              enableInfiniteScroll: false,
              scrollDirection: Axis.horizontal,
              scrollPhysics: _displayMedia.length > 1
                  ? const PageScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              onPageChanged: (index, reason) {
                setState(() => _currentPage = index);
                unawaited(_syncPostSoundPlayback());
              },
            ),
            itemBuilder: (context, index, _) =>
                _buildMediaItem(_displayMedia[index], index),
          ),

          // ── Gradient Overlay ─────────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.15, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Media Count Badge ─────────────────────────────────────────────
          if (_displayMedia.length > 1)
            Positioned(
              top:
                  MediaQuery.of(context).padding.top +
                  (widget.feedTopBarClearance ??
                      HomeLayoutConstants.feedTopTabsTopPadding),
              left: 0,
              right: 0,
              child: Center(child: _buildMediaCountBadge(_displayMedia.length)),
            ),

          // ── Side action column (right in Arabic, left in English) ────────
          Positioned(
            right: actionsOnRight ? _actionColumnInset : null,
            left: actionsOnRight ? null : _actionColumnInset,
            bottom: bottom + 20,
            child: Column(
              crossAxisAlignment: actionsOnRight
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildProfileAvatar(post.user?.avatarUrl, theme),
                const SizedBox(height: 22),
                _buildLikeButton(),
                const SizedBox(height: _actionSpacing),
                _buildTikTokAction(
                  icon: LucideIcons.messageCircleMore400,
                  label: _formatCount(widget.post.commentCount),
                  color: Colors.white,
                  onTap: _showComments,
                ),
                const SizedBox(height: _actionSpacing),
                _buildTikTokAction(
                  icon: Icons.bookmark,
                  label: _formatCount(_saveCount),
                  color: _isSaved ? _tikTokSaveYellow : Colors.white,
                  onTap: _handleSave,
                ),
                const SizedBox(height: _actionSpacing),
                _buildTikTokAction(
                  icon: LucideIcons.forward400,
                  color: Colors.white,
                  onTap: _showMoreOptions,
                ),
                const SizedBox(height: _actionSpacing),
                _buildMusicDisc(theme, post),
              ],
            ),
          ),

          // ── Bottom Info ───────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_displayMedia.length > 1) ...[
                  IgnorePointer(
                    child: _buildMediaPageDots(_displayMedia.length),
                  ),
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: EdgeInsets.only(
                    left: actionsOnRight
                        ? _contentEdgeInset
                        : _contentActionSidePadding,
                    right: actionsOnRight
                        ? _contentActionSidePadding
                        : _contentEdgeInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FeedRepostBanner(
                        post: _postWithLocalRepostState(post),
                        feedItem: widget.feedItem,
                        repostQuote: _repostQuote,
                      ),
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

                      // Description + hashtags
                      if ((post.description ?? '').isNotEmpty)
                        _PostCaptionTags(post: post, maxLines: 3)
                      else if (post.hashtags.isNotEmpty)
                        _PostHashtagChips(tags: post.hashtags),
                      const SizedBox(height: 10),
                      _buildMusicSoundLabel(post),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCountBadge(int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            '${_currentPage + 1}/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPageDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _currentPage == index ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String? avatarUrl, ThemeData theme) {
    final showFollowBadge = !_isPostOwner();
    final authorId = _postAuthorUserId();

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        StoryProfileAvatar(
          userId: authorId,
          imageUrl: avatarUrl,
          fallbackText: widget.post.user?.username ?? 'User',
          radius: _profileAvatarRadius,
          backgroundColor: Colors.white24,
          username: widget.post.user?.username,
          fullName: widget.post.user?.username,
          isFollowing: _isFollowing,
          onTap: _openAuthorProfile,
        ),
        if (showFollowBadge)
          Positioned(
            bottom: -8,
            child: GestureDetector(
              onTap: _isFollowing ? null : _handleFollow,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  gradient: _isFollowing
                      ? null
                      : LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _isFollowing ? Colors.white : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isFollowing ? Colors.white : Colors.black,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: _isFollowLoading
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        _isFollowing ? Icons.check : Icons.add,
                        color: _isFollowing
                            ? theme.colorScheme.primary
                            : Colors.white,
                        size: 12,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLikeButton() {
    return _buildTikTokAction(
      icon: Icons.favorite,
      label: _formatCount(_likeCount),
      color: _isLiked ? _tikTokLikeRed : Colors.white,
      onTap: _handleLike,
      iconWidget: ScaleTransition(
        scale: _likeScaleAnim,
        child: Icon(
          Icons.favorite,
          color: _isLiked ? _tikTokLikeRed : Colors.white,
          size: _actionIconSize,
          shadows: _actionTextShadow,
        ),
      ),
    );
  }

  Widget _buildTikTokAction({
    required IconData icon,
    String? label,
    required Color color,
    VoidCallback? onTap,
    Widget? iconWidget,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _actionHitWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _actionIconSize + 2,
              child: Center(
                child:
                    iconWidget ??
                    Icon(
                      icon,
                      color: color,
                      size: _actionIconSize,
                      shadows: _actionTextShadow,
                    ),
              ),
            ),
            if (label != null && label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: _actionLabelSize,
                  fontWeight: FontWeight.w600,
                  shadows: _actionTextShadow,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPostSound(PostEntity post) {
    final sound = post.sound;
    if (sound == null || sound.id.isEmpty) return;
    unawaited(openSoundDetail(context, soundId: sound.id));
  }

  Widget _buildMusicSoundLabel(PostEntity post) {
    final sound = post.sound;
    final l10n = AppLocalizations.of(context)!;
    final label = sound?.name ?? l10n.cameraOriginalSound;

    return GestureDetector(
      onTap: _canTogglePlayback ? () => unawaited(_togglePostPlayback()) : null,
      onLongPress: sound != null ? () => _openPostSound(post) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(right: 10, left: 10, bottom: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlurredIconBadge(
              icon: LucideIcons.music,
              diameter: 24,
              iconSize: 12,
              iconColor: Colors.white.withValues(alpha: 0.9),
              blurSigma: 10,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicDisc(ThemeData theme, PostEntity post) {
    return GestureDetector(
      onTap: _canTogglePlayback ? () => unawaited(_togglePostPlayback()) : null,
      onLongPress: post.sound != null ? () => _openPostSound(post) : null,
      child: _buildMusicDiscVisual(theme),
    );
  }

  Widget _buildMusicDiscVisual(ThemeData theme) {
    return AnimatedBuilder(
      animation: _musicController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _musicController.value * 2 * 3.14159,
          child: child,
        );
      },
      child: Container(
        width: _musicDiscSize,
        height: _musicDiscSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.8),
              theme.colorScheme.secondary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  LucideIcons.music,
                  color: Colors.white70,
                  size: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) => formatCompactCount(count);
}

const _captionHashtagColor = Color(0xFF7FDBFF);

class _PostCaptionTags extends StatelessWidget {
  const _PostCaptionTags({required this.post, this.maxLines});

  final PostEntity post;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final description = post.description!;
    final captionStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 14,
      height: 1.4,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
    );

    final inTextTags = TagParser.extractHashtagNames(
      description,
    ).map((tag) => tag.toLowerCase()).toSet();
    final extraTags = post.hashtags
        .where((tag) => !inTextTags.contains(tag.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: TaggedText(
            text: description,
            style: captionStyle,
            mentionStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
            hashtagStyle: TextStyle(
              color: _captionHashtagColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
            post: post,
            mentionUserIds: MentionRefUtils.usernameToUserIdMap(
              description,
              post.mentions,
              post: post,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            onHashtagTap: (name) => openHashtagFeed(context, name),
          ),
        ),
        if (extraTags.isNotEmpty) ...[
          const SizedBox(height: 6),
          _PostHashtagChips(tags: extraTags),
        ],
      ],
    );
  }
}

class _PostHashtagChips extends StatelessWidget {
  const _PostHashtagChips({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          GestureDetector(
            onTap: () => openHashtagFeed(context, tag),
            behavior: HitTestBehavior.opaque,
            child: Text(
              '#$tag',
              style: const TextStyle(
                color: _captionHashtagColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: _captionHashtagColor,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
      ],
    );
  }
}
