import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_caption_display.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_grouping.dart';
import 'package:bimobondapp/app/home/presentation/utils/story_l10n_format.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_insights_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_message_sheet.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_viewer_actions.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/core/data/viewed_stories_store.dart';
import 'package:bimobondapp/app/posts/presentation/utils/post_view_recorder.dart';
import 'package:bimobondapp/core/utils/app_sizes.dart';
import 'package:bimobondapp/core/utils/media_utils.dart';
import 'package:bimobondapp/core/utils/post_story_filter.dart';
import 'package:bimobondapp/core/widgets/custom_loading_widget.dart';
import 'package:bimobondapp/core/widgets/glass_bottom_sheet.dart';
import 'package:bimobondapp/core/widgets/popup_dialogs.dart';
import 'package:bimobondapp/app/home/presentation/widgets/stories/story_profile_avatar.dart';
import 'package:bimobondapp/core/navigation/story_user_navigation.dart';
import 'package:bimobondapp/core/widgets/safe_network_image.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

/// Per-segment display duration (TikTok-style auto advance).
const Duration _kStorySegmentDuration = Duration(seconds: 6);

class _StoryLocalEngagement {
  _StoryLocalEngagement({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
  });

  bool isLiked;
  int likeCount;
  int commentCount;
  int viewCount;
}

class StoriesViewerScreen extends StatefulWidget {
  const StoriesViewerScreen({
    required this.stories,
    this.initialIndex = 0,
    super.key,
  });

  final List<PostEntity> stories;
  final int initialIndex;

  @override
  State<StoriesViewerScreen> createState() => _StoriesViewerScreenState();
}

class _StoriesViewerScreenState extends State<StoriesViewerScreen>
    with TickerProviderStateMixin {
  late List<PostEntity> _stories;
  late final PageController _pageController;
  late final Map<String, _StoryLocalEngagement> _engagement;
  VideoPlayerController? _videoController;
  AnimationController? _progressController;
  int _currentIndex = 0;
  bool _paused = true;
  bool _isMediaReady = false;

  @override
  void initState() {
    super.initState();
    _stories = onlyStoryPosts(widget.stories);
    _engagement = {
      for (final s in _stories)
        s.id: _StoryLocalEngagement(
          isLiked: s.isLiked,
          likeCount: s.likeCount,
          commentCount: s.commentCount,
          viewCount: s.viewCount,
        ),
    };
    _currentIndex = widget.initialIndex.clamp(0, _stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess) {
        auth_di.sl<ViewedStoriesStore>().bindUser(authState.user.id);
      }
      if (_stories.isNotEmpty) {
        _onStoryActivated(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _disposeVideo();
    _pageController.dispose();
    super.dispose();
  }

  PostEntity? get _currentPost =>
      _stories.isEmpty ? null : _stories[_currentIndex];

  String? get _currentUserId {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthSuccess) return auth.user.id;
    return null;
  }

  bool _isOwner(PostEntity post) {
    final me = _currentUserId;
    return me != null && me == post.userId;
  }

  _StoryLocalEngagement _engagementFor(PostEntity post) =>
      _engagement[post.id] ??
      _StoryLocalEngagement(
        isLiked: post.isLiked,
        likeCount: post.likeCount,
        commentCount: post.commentCount,
        viewCount: post.viewCount,
      );

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
  }

  void _pauseProgress() {
    _paused = true;
    _progressController?.stop();
    _videoController?.pause();
  }

  void _resumeProgress() {
    _paused = false;
    _progressController?.forward();
    _videoController?.play();
  }

  void _resetProgressAnimation() {
    _progressController?.dispose();
    if (!mounted || _stories.isEmpty) return;

    _progressController =
        AnimationController(vsync: this, duration: _kStorySegmentDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !_paused && mounted) {
              _goNextStory();
            }
          });

    if (!_paused) {
      _progressController!.forward();
    }
  }

  Future<void> _initVideoForPost(PostEntity post) async {
    _disposeVideo();
    if (post.type != 'VIDEO') return;

    final url = storyDisplayMediaUrl(post);
    if (url == null || url.isEmpty) {
      if (mounted && _currentPost?.id == post.id) {
        _markMediaReady();
      }
      return;
    }

    final resolved = MediaUtils.resolveAbsoluteUrl(url);
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    } finally {
      if (mounted && _currentPost?.id == post.id) {
        _markMediaReady();
      }
    }
  }

  void _markMediaReady() {
    if (!mounted || _isMediaReady) return;
    final post = _currentPost;
    if (post == null) return;

    setState(() => _isMediaReady = true);
    _paused = false;
    _resetProgressAnimation();
    if (post.type == 'VIDEO') {
      unawaited(_videoController?.play());
    }
    _recordStoryViewIfNeeded(post);
    auth_di.sl<ViewedStoriesStore>().markViewed(post.id);
  }

  void _onStoryActivated(int index) {
    if (index < 0 || index >= _stories.length) return;

    _progressController?.dispose();
    _progressController = null;

    setState(() {
      _currentIndex = index;
      _isMediaReady = false;
      _paused = true;
    });

    final post = _stories[index];
    if (!isStoryStillActive(post)) {
      _removeStoryAt(index);
      return;
    }

    _prefetchAdjacentStoryImages(index);

    if (post.type == 'VIDEO') {
      unawaited(_initVideoForPost(post));
    } else {
      unawaited(_prepareImageStory(post));
    }
  }

  void _prefetchAdjacentStoryImages(int index) {
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= _stories.length) continue;
      final neighbor = _stories[i];
      if (neighbor.type == 'VIDEO') continue;
      final url = storyDisplayMediaUrl(neighbor);
      if (url == null || url.isEmpty) continue;
      final resolved = MediaUtils.resolveAbsoluteUrl(url);
      if (!isValidNetworkImageUrl(resolved)) continue;
      unawaited(
        precacheSafeNetworkImage(context, resolved).catchError((_) {}),
      );
    }
  }

  Future<void> _prepareImageStory(PostEntity post) async {
    final url = storyDisplayMediaUrl(post);
    if (url == null || url.isEmpty) {
      if (mounted && _currentPost?.id == post.id) {
        _markMediaReady();
      }
      return;
    }

    final resolved = MediaUtils.resolveAbsoluteUrl(url);
    if (isValidNetworkImageUrl(resolved)) {
      try {
        await precacheSafeNetworkImage(context, resolved);
      } catch (_) {
        // Show broken/blank state once ready overlay is dismissed.
      }
    }

    if (mounted && _currentPost?.id == post.id) {
      _markMediaReady();
    }
  }

  Future<void> _recordStoryViewIfNeeded(PostEntity post) async {
    final serverCount = await PostViewRecorder.recordIfNeeded(
      postId: post.id,
      isOwner: _isOwner(post),
      watchedDuration: _kStorySegmentDuration.inSeconds,
      checkStoryHistory: true,
      isStory: true,
    );
    if (!mounted || serverCount == null) return;

    final e = _engagementFor(post);
    setState(() {
      if (serverCount > e.viewCount) {
        e.viewCount = serverCount;
      } else {
        e.viewCount++;
      }
    });
  }

  void _goNextStory() {
    if (_currentIndex < _stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      context.pop();
    }
  }

  void _goPreviousStory() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      context.pop();
    }
  }

  void _removeStoryAt(int index) {
    if (!mounted) return;
    setState(() {
      final removed = _stories.removeAt(index);
      _engagement.remove(removed.id);
      if (_stories.isEmpty) {
        context.pop();
        return;
      }
      if (_currentIndex >= _stories.length) {
        _currentIndex = _stories.length - 1;
      }
    });
    _onStoryActivated(_currentIndex);
  }

  void _handleLike(PostEntity post) {
    final e = _engagementFor(post);
    final liked = !e.isLiked;
    setState(() {
      e.isLiked = liked;
      e.likeCount += liked ? 1 : -1;
      if (e.likeCount < 0) e.likeCount = 0;
      _engagement[post.id] = e;
    });
    context.read<PostsBloc>().add(
      ToggleLikePostRequestedEvent(post.id, liked: liked),
    );
  }

  void _openStoryMessage(PostEntity post) {
    if (_isOwner(post)) return;
    _pauseProgress();
    StoryMessageSheet.show(context, story: post).whenComplete(() {
      if (mounted) _resumeProgress();
    });
  }

  void _openStoryViewers(PostEntity post) {
    _pauseProgress();
    final e = _engagementFor(post);
    var keepPausedForDelete = false;
    StoryInsightsSheet.show(
      context,
      post: post,
      viewCount: e.viewCount,
      likeCount: e.likeCount,
      onDelete: () {
        keepPausedForDelete = true;
        _confirmDelete(post);
      },
    ).whenComplete(() {
      if (mounted && !keepPausedForDelete) _resumeProgress();
    });
  }

  void _showStoryOptions(PostEntity post) {
    _pauseProgress();
    final l10n = AppLocalizations.of(context)!;
    var openedConfirm = false;

    GlassBottomSheet.showActions<void>(
      context,
      children: [
        GlassBottomSheetListTile(
          label: l10n.deletePost,
          destructive: true,
          icon: LucideIcons.trash2,
          onTap: () {
            openedConfirm = true;
            Navigator.pop(context);
            _confirmDelete(post);
          },
        ),
      ],
    ).whenComplete(() {
      if (mounted && !openedConfirm) _resumeProgress();
    });
  }

  void _confirmDelete(PostEntity post) {
    final l10n = AppLocalizations.of(context)!;
    GlassBottomSheet.showConfirm(
      context,
      title: l10n.deletePostTitle,
      message: l10n.deletePostMessage,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteAction,
      destructive: true,
      onConfirm: () {
        context.read<PostsBloc>().add(
          DeletePostRequestedEvent(post.id, isStory: true),
        );
      },
    ).whenComplete(() {
      if (mounted) _resumeProgress();
    });
  }

  void _onDeleteSuccess(String postId) {
    final index = _stories.indexWhere((s) => s.id == postId);
    if (index == -1) return;
    _removeStoryAt(index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<PostsBloc, PostsState>(
      listenWhen: (_, current) =>
          current is DeletePostSuccess ||
          current is LikePostSuccess ||
          current is PostsFailure,
      listener: (context, state) {
        if (state is DeletePostSuccess) {
          _onDeleteSuccess(state.postId);
        } else if (state is PostsFailure) {
          PopupDialogs.showErrorDialog(context, state.message);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _stories.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.storyExpired,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _stories.length,
                    onPageChanged: _onStoryActivated,
                    itemBuilder: (context, index) {
                      return _StoryPageContent(
                        key: ValueKey(_stories[index].id),
                        post: _stories[index],
                        videoController: index == _currentIndex
                            ? _videoController
                            : null,
                      );
                    },
                  ),
                  if (!_isMediaReady)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black,
                        child: Center(child: CustomLoadingWidget(size: 48)),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                            stops: const [0.0, 0.2, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: _buildStoryTapZones()),
                  SafeArea(child: _buildTopBar(l10n)),
                  if (_currentPost != null) _buildBottomOverlay(l10n),
                ],
              ),
      ),
    );
  }

  /// Left half → previous story; right half → next (under chrome, above media).
  Widget _buildStoryTapZones() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _goPreviousStory,
            onLongPressStart: (_) => _pauseProgress(),
            onLongPressEnd: (_) => _resumeProgress(),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _goNextStory,
            onLongPressStart: (_) => _pauseProgress(),
            onLongPressEnd: (_) => _resumeProgress(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    final post = _currentPost!;
    final progress = _progressController;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.p8,
            AppSizes.p6,
            AppSizes.p8,
            AppSizes.p8,
          ),
          child: Row(
            children: List.generate(_stories.length, (i) {
              final isPast = i < _currentIndex;
              final isActive = i == _currentIndex;
              return Expanded(
                child: Container(
                  height: 2.5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: isPast
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        )
                      : (isActive && progress != null && _isMediaReady
                          ? AnimatedBuilder(
                              animation: progress,
                              builder: (context, child) {
                                return Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: FractionallySizedBox(
                                    widthFactor:
                                        progress.value.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : null),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    StoryProfileAvatar(
                      userId: post.user?.id,
                      imageUrl: post.user?.avatarUrl,
                      radius: 16,
                      fallbackText:
                          post.user?.fullName ?? post.user?.username ?? '',
                      username: post.user?.username,
                      fullName: post.user?.fullName,
                      onTap: () {
                        final id = post.user?.id.trim() ?? '';
                        if (id.isEmpty) return;
                        openUserStoryOrProfile(
                          context,
                          userId: id,
                          username: post.user?.username,
                          fullName: post.user?.fullName,
                          avatarUrl: post.user?.avatarUrl,
                        );
                      },
                    ),
                    const SizedBox(width: AppSizes.p8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.user?.fullName?.trim().isNotEmpty == true
                                ? post.user!.fullName!.trim()
                                : (post.user?.username ?? ''),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            formatStoryTimeAgo(post, l10n),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isOwner(post))
                IconButton(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () => _showStoryOptions(post),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomOverlay(AppLocalizations l10n) {
    final post = _currentPost!;
    final caption = StoryCaptionUtils.plainCaption(post.description);
    final e = _engagementFor(post);
    final isOwner = _isOwner(post);

    return Positioned(
      left: AppSizes.p16,
      right: AppSizes.p16,
      bottom: MediaQuery.paddingOf(context).bottom + AppSizes.p16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner) ...[
            StoryViewerViewersChip(
              viewCount: e.viewCount,
              label: l10n.viewsLabel.toLowerCase(),
              onTap: () => _openStoryViewers(post),
            ),
            const SizedBox(height: AppSizes.p10),
          ],
          if (caption.isNotEmpty) ...[
            Center(child: StoryCaptionDisplay(caption: caption)),
            const SizedBox(height: AppSizes.p12),
          ],
          StoryViewerBottomActions(
            isLiked: e.isLiked,
            onLike: () => _handleLike(post),
            onMessage: isOwner ? null : () => _openStoryMessage(post),
            messageHint: l10n.storySendMessageHint,
          ),
        ],
      ),
    );
  }
}

class _StoryPageContent extends StatelessWidget {
  const _StoryPageContent({
    super.key,
    required this.post,
    this.videoController,
  });

  final PostEntity post;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    if (post.type == 'VIDEO' &&
        videoController != null &&
        videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: videoController!.value.size.width,
            height: videoController!.value.size.height,
            child: VideoPlayer(videoController!),
          ),
        ),
      );
    }

    if (post.type == 'VIDEO') {
      return const ColoredBox(color: Colors.black);
    }

    final url = storyDisplayMediaUrl(post);
    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
    }

    return SizedBox.expand(
      child: SafeNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        blankOnError: true,
        showLoadingIndicator: false,
      ),
    );
  }
}
