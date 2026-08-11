import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/utils/post_owner_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_post_utils.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_empty_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_media_preloader.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_top_bar.dart';
import 'package:bimobondapp/app/shop/presentation/cubit/shop_cart_cubit.dart';
import 'package:bimobondapp/app/shop/presentation/pages/ecommerce_home_screen.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_posts_viewer_layout.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_stack.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_tab.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart'
    as auth_di;
import 'package:bimobondapp/app/notifications/presentation/di/notifications_injector.dart'
    as notifications_di;
import 'package:bimobondapp/app/notifications/presentation/services/notification_coordinator.dart';
import 'package:bimobondapp/core/services/app_location_service.dart';
import 'package:bimobondapp/core/services/feed_video_disk_prefetcher.dart';
import 'package:bimobondapp/core/services/feed_video_prewarmer.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/post_entity.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_auction_query.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
import 'package:bimobondapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeFeedScreen extends StatefulWidget {
  final bool isTabActive;

  const HomeFeedScreen({super.key, this.isTabActive = true});

  @override
  State<HomeFeedScreen> createState() => HomeFeedScreenState();
}

class HomeFeedScreenState extends State<HomeFeedScreen> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _bottomChromeRevision = ValueNotifier(0);
  final List<FeedItemEntity> _feedItems = [];
  String? _nextCursor;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;
  int _currentPostIndex = 0;
  bool _awaitingInitialFeed = true;
  bool _feedLoadFailed = false;
  String? _feedErrorMessage;
  bool _expectingInitialFeed = false;
  HomeFeedTab _selectedFeedTab = HomeFeedTab.forYou;
  Completer<void>? _pullRefreshCompleter;
  final FeedVideoProgressNotifier _feedVideoProgress =
      FeedVideoProgressNotifier();
  final FeedMediaPreloader _mediaPreloader = FeedMediaPreloader();
  bool _didRunPostFeedBootstrap = false;

  /// Distinct posts viewed this session — used for every-N interest prompt.
  final Set<String> _sessionViewedPostIds = <String>{};
  String? _interestPromptPostId;

  FeedVideoProgressNotifier get feedVideoProgress => _feedVideoProgress;

  Listenable get bottomChromeListenable => _bottomChromeRevision;

  bool get _showInterestPrompt {
    if (_interestPromptPostId == null || _feedItems.isEmpty) return false;
    final current =
        _feedItems[_currentPostIndex.clamp(0, _feedItems.length - 1)];
    return current.post.id == _interestPromptPostId;
  }

  double feedMediaBottomInset(BuildContext context, PostEntity post) {
    final base =
        FeedVideoPostsViewerLayout.homeFeedBottomNavReservedHeight(context);
    if (post.isAuctionable) return base;
    if (_showInterestPrompt && post.id == _interestPromptPostId) {
      return base + HomeLayoutConstants.feedInterestPromptHeight;
    }
    return base;
  }

  void _notifyBottomChromeLayout() => _bottomChromeRevision.value++;

  void patchFeedPost(
    String postId,
    PostEntity Function(PostEntity post) patch,
  ) {
    final index = _feedItems.indexWhere((item) => item.post.id == postId);
    if (index == -1) return;
    setState(() {
      _feedItems[index] = _feedItems[index].copyWith(
        post: patch(_feedItems[index].post),
      );
    });
  }

  Widget? buildBottomSearchProgressColumn() => null;

  /// Called when the user re-taps the Home tab while already on it.
  void refreshFromTab() {
    if (!mounted) return;
    _beginVisibleRefresh();
  }

  @override
  void initState() {
    super.initState();
    context.read<ShopCartCubit>().refresh();
    if (widget.isTabActive) {
      _loadTabData();
    }
  }

  @override
  void didUpdateWidget(HomeFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      // Coming back from another tab keeps the user's place in the feed.
      // Only load when there is nothing to show yet; a full refresh happens
      // solely when the user re-taps Home while already on it
      // (refreshFromTab).
      if (_feedItems.isEmpty) {
        _loadTabData();
      }
    } else if (!widget.isTabActive && oldWidget.isTabActive) {
      _feedVideoProgress.reset();
    }
  }

  /// Clear content and show skeleton while posts reload (Home icon tap).
  void _beginVisibleRefresh() {
    setState(() {
      _currentPostIndex = 0;
      _feedLoadFailed = false;
      _feedErrorMessage = null;
      _awaitingInitialFeed = true;
      _feedItems.clear();
      _interestPromptPostId = null;
    });
    _feedVideoProgress.reset();
    _notifyBottomChromeLayout();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _loadTabData();
  }

  void _loadTabData() {
    // Location is resolved after first paint; do not send lat/lng on home
    // (disables server Redis cache per feed-performance guide).
    _fetchFeed(refresh: true);
  }

  void _runPostFeedBootstrap() {
    if (_didRunPostFeedBootstrap) return;
    _didRunPostFeedBootstrap = true;

    notifications_di.sl<NotificationCoordinator>().allowLoginSideEffects();
    unawaited(auth_di.sl<AppLocationService>().ensureViewerLocation());
  }

  @override
  void dispose() {
    _bottomChromeRevision.dispose();
    _feedVideoProgress.dispose();
    _pageController.dispose();
    FeedVideoPrewarmer.instance.clear();
    FeedVideoDiskPrefetcher.instance.clear();
    super.dispose();
  }

  void _fetchFeed({bool refresh = false}) {
    if (refresh) {
      _nextCursor = null;
      _hasReachedMax = false;
      _feedLoadFailed = false;
      _feedErrorMessage = null;
      _expectingInitialFeed = true;
      if (_feedItems.isEmpty && mounted) {
        setState(() => _awaitingInitialFeed = true);
      }
    } else if (_hasReachedMax) {
      return;
    } else if (_feedItems.isEmpty) {
      _expectingInitialFeed = true;
    }

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        // Cursor pagination: first/refresh omit cursor; load-more passes nextCursor.
        cursor: refresh ? null : _nextCursor,
        limit: HomeLayoutConstants.feedPageSize,
        isRefresh: refresh,
        isStory: false,
        sort: _selectedFeedTab.feedSort,
        from: _selectedFeedTab.feedFrom,
        // Auctions belong on the Auctions tab only.
        auctionQuery: const FeedAuctionQuery(isAuctionable: false),
      ),
    );
  }

  void _onFeedTabChanged(HomeFeedTab tab) {
    if (_selectedFeedTab == tab) return;
    setState(() {
      _selectedFeedTab = tab;
      _currentPostIndex = 0;
      _awaitingInitialFeed = true;
      _feedLoadFailed = false;
      _feedErrorMessage = null;
      _interestPromptPostId = null;
    });
    _feedVideoProgress.reset();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _fetchFeed(refresh: true);
  }

  void _loadMorePosts() {
    if (_isLoadingMore || _hasReachedMax || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);
    _fetchFeed();
  }

  void _mergeFeedItems(List<FeedItemEntity> incoming, {required bool replace}) {
    // Belt-and-suspenders if the API still returns auction posts.
    final nonAuctions = incoming
        .where((item) => !item.post.isAuctionable)
        .toList(growable: false);
    if (replace) {
      _feedItems
        ..clear()
        ..addAll(nonAuctions);
      return;
    }
    final existingIds = _feedItems.map((item) => item.id).toSet();
    _feedItems.addAll(
      nonAuctions.where((item) => !existingIds.contains(item.id)),
    );
  }

  Future<void> _onPullToRefresh() async {
    _pullRefreshCompleter = Completer<void>();
    _fetchFeed(refresh: true);
    try {
      await _pullRefreshCompleter!.future.timeout(
        HomeLayoutConstants.tabRefreshTimeout,
      );
    } catch (_) {
      // Timeout or cancelled — dismiss refresh indicator.
    } finally {
      _pullRefreshCompleter = null;
    }
  }

  void _completePullRefreshIfPending() {
    final completer = _pullRefreshCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _onFeedPageChanged(int index) {
    if (_feedItems.isEmpty) return;

    _feedVideoProgress.reset();
    setState(() {
      _currentPostIndex = index;
      _updateInterestPromptForIndex(index);
    });
    _notifyBottomChromeLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _feedVideoProgress.notifyListeners();
    });
    _mediaPreloader.preloadAround(context, _feedItems, index);

    final threshold =
        _feedItems.length <= HomeLayoutConstants.feedPrefetchMinPosts
        ? 0
        : _feedItems.length - HomeLayoutConstants.feedPrefetchThresholdOffset;
    if (index >= threshold) {
      _loadMorePosts();
    }
  }

  void _updateInterestPromptForIndex(int index) {
    if (_feedItems.isEmpty) return;
    final post = _feedItems[index.clamp(0, _feedItems.length - 1)].post;

    // Hide when leaving a prompted post without answering.
    if (_interestPromptPostId != null && _interestPromptPostId != post.id) {
      _interestPromptPostId = null;
    }

    if (post.isAuctionable || isCurrentUserPostOwner(context, post)) {
      return;
    }

    final isFirstView = _sessionViewedPostIds.add(post.id);
    if (!isFirstView) return;

    final every = HomeLayoutConstants.feedInterestPromptEveryNPosts;
    if (_sessionViewedPostIds.length % every == 0) {
      _interestPromptPostId = post.id;
    }
  }

  void _dismissInterestPrompt() {
    if (_interestPromptPostId == null) return;
    setState(() => _interestPromptPostId = null);
    _notifyBottomChromeLayout();
  }

  void _onInterestPromptYes() {
    final l10n = AppLocalizations.of(context)!;
    _dismissInterestPrompt();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.feedInterestPromptThanks)),
    );
  }

  void _onInterestPromptNo() {
    final postId = _interestPromptPostId;
    if (postId == null) return;
    final l10n = AppLocalizations.of(context)!;
    _dismissInterestPrompt();
    context.read<PostsBloc>().add(HidePostFromFeedEvent(postId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.postNotInterestedApplied)),
    );
  }

  void _handlePostsState(BuildContext context, PostsState state) {
    final theme = Theme.of(context);

    if (state is FeedLoadSuccess) {
      final isFirstPage = state.isFirstPage;
      final countBefore = _feedItems.length;
      setState(() {
        _feedLoadFailed = false;
        _feedErrorMessage = null;
        if (isFirstPage) {
          _awaitingInitialFeed = false;
          _expectingInitialFeed = false;
        }
        _mergeFeedItems(state.items, replace: isFirstPage);
        _nextCursor = state.nextCursor;
        if (isFirstPage) {
          _currentPostIndex = 0;
          _updateInterestPromptForIndex(0);
        } else if (_currentPostIndex >= _feedItems.length) {
          _currentPostIndex = _feedItems.length - 1;
        }
        final added = _feedItems.length - countBefore;
        if (!isFirstPage && (state.items.isEmpty || added == 0)) {
          _hasReachedMax = true;
          _nextCursor = null;
        } else {
          _hasReachedMax = state.hasReachedMax;
        }
        _isLoadingMore = false;
      });
      _notifyBottomChromeLayout();
      if (isFirstPage) {
        _completePullRefreshIfPending();
        _mediaPreloader.reset();
        if (_selectedFeedTab == HomeFeedTab.forYou) {
          _runPostFeedBootstrap();
        }
      }
      // Warm the next post's media (first slide / video poster / avatar) so
      // scrolling to it shows content immediately.
      _mediaPreloader.preloadAround(context, _feedItems, _currentPostIndex);
    } else if (state is CreatePostSuccess) {
      if (!state.post.isStory) {
        _fetchFeed(refresh: true);
      }
    } else if (state is UpdatePostSuccess) {
      _fetchFeed(refresh: true);
    } else if (state is DeletePostSuccess) {
      setState(() {
        final index = _feedItems.indexWhere(
          (item) => item.post.id == state.postId,
        );
        if (index != -1) {
          _feedItems.removeAt(index);
          if (_feedItems.isEmpty) {
            _nextCursor = null;
            _hasReachedMax = false;
          } else if (index > 0 && _pageController.hasClients) {
            _pageController.jumpToPage(index - 1);
          }
        }
      });
    } else if (state is LikePostSuccess) {
      patchFeedPost(
        state.postId,
        (post) => patchFeedPostLike(post, liked: state.liked),
      );
    } else if (state is SavePostSuccess) {
      patchFeedPost(state.postId, patchFeedPostSaveToggle);
    } else if (state is RepostPostSuccess) {
      patchFeedPost(
        state.postId,
        (post) => patchFeedPostRepost(post, isReposted: state.isReposted),
      );
    } else if (state is PostHiddenFromFeedState) {
      setState(() {
        if (_interestPromptPostId == state.postId) {
          _interestPromptPostId = null;
        }
        final index = _feedItems.indexWhere(
          (item) => item.post.id == state.postId,
        );
        if (index != -1) {
          _feedItems.removeAt(index);
          if (_feedItems.isEmpty) {
            _nextCursor = null;
            _hasReachedMax = false;
          } else if (_pageController.hasClients) {
            final next = index.clamp(0, _feedItems.length - 1);
            _currentPostIndex = next;
            _pageController.jumpToPage(next);
          }
        }
      });
      _notifyBottomChromeLayout();
    } else if (state is PostsFailure) {
      // Ignore unrelated PostsBloc failures (likes, stories, profile grids, etc.).
      final isFeedInitialFailure =
          _expectingInitialFeed && state.profileLoadKey == null;
      setState(() {
        if (isFeedInitialFailure) {
          _awaitingInitialFeed = false;
          _expectingInitialFeed = false;
          if (_feedItems.isEmpty) {
            _feedLoadFailed = true;
            _feedErrorMessage = state.message;
          }
        }
        _isLoadingMore = false;
      });
      if (isFeedInitialFailure) {
        _completePullRefreshIfPending();
      }
      // Prefer in-place retry UI when the feed is empty; snackbar when content remains.
      if (isFeedInitialFailure && _feedItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _withPersistentTopBar(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: BlocBuilder<AuthBloc, AuthState>(
            buildWhen: (previous, current) =>
                (previous is AuthSuccess) != (current is AuthSuccess),
            builder: (context, authState) {
              final isLoggedIn = authState is AuthSuccess;
              return BlocBuilder<ShopCartCubit, int>(
                builder: (context, cartCount) {
                  return FeedTopBar(
                    selectedTab: _selectedFeedTab,
                    onTabChanged: _onFeedTabChanged,
                    onLiveTap: () => context.pushFromFeed('lives'),
                    onShopTap: isLoggedIn
                        ? () => context.pushFromFeed(
                              EcommerceHomeScreen.routeName,
                            )
                        : null,
                    onSearchTap: () => context.pushFromFeed('posts_search'),
                    shopCartBadge: isLoggedIn ? cartCount : 0,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedOverlay = FeedOverlayTheme.of(context);

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (!widget.isTabActive) return;
        if (authState is AuthSuccess || authState is AuthInitial) {
          _fetchFeed(refresh: true);
        }
        if (authState is AuthSuccess) {
          context.read<ShopCartCubit>().refresh();
        } else if (authState is AuthInitial) {
          context.read<ShopCartCubit>().clear();
        }
      },
      child: Scaffold(
        backgroundColor: feedOverlay.feedBackground,
        body: BlocConsumer<PostsBloc, PostsState>(
          listener: _handlePostsState,
          builder: (context, state) {
            final theme = Theme.of(context);
            final isLoadingFirstFeed =
                _awaitingInitialFeed ||
                (_feedItems.isEmpty &&
                    (state is PostsLoading || state is PostsInitial));

            Widget wrapRefresh(Widget child) {
              return RefreshIndicator(
                onRefresh: _onPullToRefresh,
                displacement: HomeLayoutConstants.tabRefreshDisplacement,
                color: theme.colorScheme.primary,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: child,
                      ),
                    );
                  },
                ),
              );
            }

            if (isLoadingFirstFeed) {
              return _withPersistentTopBar(wrapRefresh(const FeedSkeleton()));
            }

            if (_feedItems.isEmpty && _feedLoadFailed) {
              return _withPersistentTopBar(
                wrapRefresh(
                  FeedLoadErrorState(
                    message: _feedErrorMessage,
                    onRetry: () => _fetchFeed(refresh: true),
                  ),
                ),
              );
            }

            if (_feedItems.isEmpty) {
              return _withPersistentTopBar(wrapRefresh(const FeedEmptyState()));
            }

            return _withPersistentTopBar(
              RefreshIndicator(
                onRefresh: _onPullToRefresh,
                displacement: HomeLayoutConstants.tabRefreshDisplacement,
                color: theme.colorScheme.primary,
                child: FeedVideoProgressScope(
                  notifier: _feedVideoProgress,
                  child: HomeFeedStack(
                    pageController: _pageController,
                    feedItems: _feedItems,
                    currentPostIndex: _currentPostIndex,
                    isTabActive: widget.isTabActive,
                    onPageChanged: _onFeedPageChanged,
                    bottomChromeListenable: bottomChromeListenable,
                    mediaBottomInsetFor: feedMediaBottomInset,
                    onFeedPostPatch: patchFeedPost,
                    trafficSource: _selectedFeedTab.trafficSource,
                    showInterestPrompt: _showInterestPrompt,
                    onInterestPromptYes: _onInterestPromptYes,
                    onInterestPromptNo: _onInterestPromptNo,
                    onInterestPromptDismiss: _dismissInterestPrompt,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
