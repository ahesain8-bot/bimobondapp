import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/pages/live_details_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/comment_sheet_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_media_preloader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_posts_viewer_layout.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_search_progress_column.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_scrub_time_overlay.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/video_post_widget.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_sort.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_posts_viewer_chrome.dart';
import 'package:bimobondapp/app/home/presentation/widgets/profile/profile_tab_posts_state.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/constants/profile_layout_constants.dart';
import 'package:bimobondapp/core/navigation/profile_posts_navigation.dart';
import 'package:bimobondapp/core/utils/one_page_scroll_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePostsViewerScreen extends StatefulWidget {
  const ProfilePostsViewerScreen({required this.args, super.key});

  final ProfilePostsOpenArgs args;

  @override
  State<ProfilePostsViewerScreen> createState() =>
      _ProfilePostsViewerScreenState();
}

class _ProfilePostsViewerScreenState extends State<ProfilePostsViewerScreen> {
  late final PageController _pageController;
  late List<PostEntity> _posts;
  late int _currentIndex;
  late int _page;
  late bool _hasReachedMax;

  final FeedMediaPreloader _mediaPreloader = FeedMediaPreloader();
  final FeedVideoProgressNotifier _videoProgress = FeedVideoProgressNotifier();

  bool _isLoadingMore = false;
  int? _pendingLoadKey;

  @override
  void initState() {
    super.initState();
    _posts = List<PostEntity>.from(widget.args.posts);
    _currentIndex = widget.args.initialIndex.clamp(0, _posts.length - 1);
    _page = widget.args.page;
    _hasReachedMax = widget.args.hasReachedMax;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mediaPreloader.preloadPostsAround(context, _posts, _currentIndex);
      _maybeLoadMore(_currentIndex);
    });
  }

  @override
  void dispose() {
    _mediaPreloader.reset();
    _videoProgress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _videoProgress.reset();
    _mediaPreloader.preloadPostsAround(context, _posts, index);
    _maybeLoadMore(index);
  }

  void _maybeLoadMore(int index) {
    if (_hasReachedMax || _isLoadingMore) return;
    final threshold = _posts.length <= HomeLayoutConstants.feedPrefetchMinPosts
        ? 0
        : _posts.length - HomeLayoutConstants.feedPrefetchThresholdOffset;
    if (index < threshold) return;
    _fetchNextPage();
  }

  void _fetchNextPage() {
    if (_hasReachedMax || _isLoadingMore) return;

    final authState = context.read<AuthBloc>().state;
    if (widget.args.source == ProfilePostsViewerSource.userPosts) {
      // userPosts handled below.
    } else if (authState is! AuthSuccess) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _page++;
    });

    final loadKey = DateTime.now().microsecondsSinceEpoch;
    _pendingLoadKey = loadKey;
    final nextPage = _page;
    final currentUserId = authState is AuthSuccess ? authState.user.id : null;

    switch (widget.args.source) {
      case ProfilePostsViewerSource.ownReposts:
        context.read<PostsBloc>().add(
          FetchMyRepostsRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownPosts:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            userId: widget.args.userId ?? currentUserId,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            contentType: FeedContentType.all,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownOnlyMe:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            userId: widget.args.userId ?? currentUserId,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            privacyStatus: ProfileLayoutConstants.onlyMePrivacyStatus,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownLiked:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isLiked: true,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.ownSaved:
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isSaved: true,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
        return;
      case ProfilePostsViewerSource.userPosts:
        final userId = widget.args.userId;
        if (userId == null || userId.isEmpty) {
          setState(() {
            _isLoadingMore = false;
            _page--;
          });
          return;
        }
        context.read<PostsBloc>().add(
          FetchFeedRequestedEvent(
            page: nextPage,
            limit: ProfileTabPostsState.pageSize,
            userId: userId,
            sort: ProfileLayoutConstants.postsSortNewestFirst,
            isStory: false,
            profileLoadKey: loadKey,
          ),
        );
    }
  }

  void _mergeIncoming(List<PostEntity> incoming, bool hasReachedMax) {
    if (!mounted || _pendingLoadKey == null) return;

    var merged = incoming;
    if (widget.args.source == ProfilePostsViewerSource.ownPosts) {
      merged = incoming
          .where(
            (post) =>
                post.privacyStatus !=
                ProfileLayoutConstants.onlyMePrivacyStatus,
          )
          .toList();
    }

    final existingIds = _posts.map((p) => p.id).toSet();
    _posts.addAll(merged.where((p) => !existingIds.contains(p.id)));
    sortProfilePostsNewestFirst(_posts);

    setState(() {
      _hasReachedMax = hasReachedMax;
      _isLoadingMore = false;
      _pendingLoadKey = null;
    });
    if (mounted) {
      _mediaPreloader.preloadPostsAround(context, _posts, _currentIndex);
    }
  }

  void _onLikePostSuccess(LikePostSuccess state) {
    final index = _posts.indexWhere((p) => p.id == state.postId);
    if (index == -1) return;

    if (!state.liked &&
        widget.args.source == ProfilePostsViewerSource.ownLiked) {
      setState(() {
        _posts.removeAt(index);
        if (_currentIndex >= _posts.length) {
          _currentIndex = (_posts.length - 1).clamp(0, _posts.length);
        }
      });
      if (_posts.isEmpty && mounted) {
        Navigator.of(context).maybePop();
      }
      return;
    }

    final post = _posts[index];
    final nextCount = state.liked
        ? post.likeCount + (post.isLiked ? 0 : 1)
        : (post.likeCount - (post.isLiked ? 1 : 0)).clamp(0, 1 << 30).toInt();
    setState(() {
      _posts[index] = post.copyWith(isLiked: state.liked, likeCount: nextCount);
    });
  }

  Future<void> _openCommentsForCurrentPost() async {
    if (_posts.isEmpty) return;
    final post = _posts[_currentIndex.clamp(0, _posts.length - 1)];
    final authState = context.read<AuthBloc>().state;
    final isOwner =
        authState is AuthSuccess && authState.user.id == post.userId;
    final latestCount = await CommentSheetWidget.show(
      context,
      postId: post.id,
      postOwnerId: post.userId,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      viewCount: post.viewCount,
      isPostOwner: isOwner,
    );
    if (latestCount == null || !mounted) return;
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;
    setState(() {
      _posts[index] = _posts[index].copyWith(commentCount: latestCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostsBloc, PostsState>(
      listener: (context, state) {
        if (state is ProfilePostsLoadSuccess &&
            state.profileLoadKey == _pendingLoadKey) {
          _mergeIncoming(state.posts, state.hasReachedMax);
          return;
        }
        if (state is MyRepostsLoadSuccess &&
            state.profileLoadKey == _pendingLoadKey) {
          _mergeIncoming(state.posts, state.hasReachedMax);
          return;
        }
        if (state is PostsFailure && state.profileLoadKey == _pendingLoadKey) {
          setState(() {
            if (_page > widget.args.page) _page--;
            _isLoadingMore = false;
            _pendingLoadKey = null;
          });
          return;
        }
        if (state is DeletePostSuccess) {
          final deletedId = state.postId;
          if (!_posts.any((p) => p.id == deletedId)) return;
          setState(() {
            _posts.removeWhere((p) => p.id == deletedId);
            if (_currentIndex >= _posts.length) {
              _currentIndex = _posts.length - 1;
            }
          });
          if (_posts.isEmpty && mounted) {
            Navigator.of(context).maybePop();
          }
        } else if (state is LikePostSuccess) {
          _onLikePostSuccess(state);
        } else if (state is UpdatePostSuccess) {
          final index = _posts.indexWhere((p) => p.id == state.post.id);
          if (index != -1) {
            setState(() => _posts[index] = state.post);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: FeedVideoProgressScope(
          notifier: _videoProgress,
          child: _posts.isEmpty
              ? const SizedBox.shrink()
              : Builder(
                  builder: (context) {
                    final current =
                        _posts[_currentIndex.clamp(0, _posts.length - 1)];
                    final currentHasVideo = feedPostHasVideo(current);
                    final showTopSearch = feedPostShowsProfileSearchChrome(
                      current,
                    );
                    final bottomChrome =
                        FeedVideoPostsViewerLayout.profileCommentBarStackHeight(
                          context,
                        );
                    final progressBottom =
                        FeedVideoPostsViewerLayout.progressColumnBottom(
                          bottomChrome,
                        );
                    final topClearance = ProfilePostsViewerTopBar.stackHeight(
                      context,
                    );

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          allowImplicitScrolling: false,
                          physics: const OnePageScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          itemCount: _posts.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            if (post.isAuctionable) {
                              return LiveDetailsScreen(
                                post: post,
                                embeddedInFeed: true,
                                auctionId: post.auction?.id,
                              );
                            }
                            return VideoPostWidget(
                              key: ValueKey('profile_post_${post.id}'),
                              post: post,
                              isActive: index == _currentIndex,
                              respectFeedPlaybackGate: false,
                              animateChromeEntrance: true,
                              bottomPadding:
                                  FeedVideoPostsViewerLayout.videoContentBottomPadding(
                                    bottomChromeStackHeight: bottomChrome,
                                    post: post,
                                    captionGap: HomeLayoutConstants
                                        .feedCaptionGapBelowSearchChrome,
                                    showProgressBar: feedPostHasVideo(post),
                                    showSearchRow: true,
                                  ),
                              feedTopBarClearance: topClearance,
                              pageController: _pageController,
                              pageIndex: index,
                              feedMediaFit: BoxFit.cover,
                            );
                          },
                        ),
                        const Positioned.fill(
                          child: FeedVideoScrubTimeOverlay(),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.55),
                                  Colors.black.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                            child: ProfilePostsViewerTopBar(
                              onBack: () => Navigator.of(context).maybePop(),
                              post: current,
                              showSearch: showTopSearch,
                            ),
                          ),
                        ),
                        if (showTopSearch)
                          Positioned(
                            key: ValueKey('chrome_${_posts[_currentIndex].id}'),
                            left: 0,
                            right: 0,
                            bottom: progressBottom,
                            child: FeedVideoSearchProgressColumn(
                              post: current,
                              transparentBackground: true,
                              showProgressBar: currentHasVideo,
                              showSearchRow: true,
                            ),
                          ),
                        if (!current.isAuctionable)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ProfilePostsViewerCommentBar(
                              onTap: _openCommentsForCurrentPost,
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
