import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_empty_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_top_bar.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_stack.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_tab.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/core/services/app_location_service.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:bimobondapp/core/navigation/feed_navigation.dart';
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
  final List<FeedItemEntity> _feedItems = [];
  int _feedPage = 1;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;
  int _currentPostIndex = 0;
  bool _awaitingInitialFeed = true;
  bool _feedLoadFailed = false;
  String? _feedErrorMessage;
  bool _expectingFeedPage1 = false;
  HomeFeedTab _selectedFeedTab = HomeFeedTab.forYou;
  Completer<void>? _pullRefreshCompleter;
  final FeedVideoProgressNotifier _feedVideoProgress =
      FeedVideoProgressNotifier();

  /// Called when the user re-taps the Home tab while already on it.
  void refreshFromTab() {
    if (!mounted) return;
    _beginVisibleRefresh();
  }

  @override
  void initState() {
    super.initState();
    if (widget.isTabActive) {
      _loadTabData();
    }
  }

  @override
  void didUpdateWidget(HomeFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTabActive && !oldWidget.isTabActive) {
      _beginVisibleRefresh();
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
    });
    _feedVideoProgress.reset();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _loadTabData();
  }

  void _loadTabData() {
    unawaited(_loadTabDataWithLocation());
  }

  Future<void> _loadTabDataWithLocation() async {
    await auth_di.sl<AppLocationService>().ensureViewerLocation();
    if (!mounted) return;
    _fetchFeed(refresh: true);
  }

  @override
  void dispose() {
    _feedVideoProgress.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _fetchFeed({bool refresh = false}) {
    if (refresh) {
      _feedPage = 1;
      _hasReachedMax = false;
      _feedLoadFailed = false;
      _feedErrorMessage = null;
      _expectingFeedPage1 = true;
      if (_feedItems.isEmpty && mounted) {
        setState(() => _awaitingInitialFeed = true);
      }
    } else if (_hasReachedMax) {
      return;
    } else if (_feedPage == 1) {
      _expectingFeedPage1 = true;
    }

    final viewerLocation = auth_di.sl<UserLocationStore>().viewerCoordinates;

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: _feedPage,
        limit: HomeLayoutConstants.feedPageSize,
        isRefresh: refresh,
        isStory: false,
        sort: _selectedFeedTab.feedSort,
        from: _selectedFeedTab.feedFrom,
        latitude: viewerLocation?.latitude,
        longitude: viewerLocation?.longitude,
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
    });
    _feedVideoProgress.reset();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _fetchFeed(refresh: true);
  }

  void _loadMorePosts() {
    if (_isLoadingMore || _hasReachedMax) return;
    setState(() => _isLoadingMore = true);
    _feedPage++;
    _fetchFeed();
  }

  void _mergeFeedItems(List<FeedItemEntity> incoming, {required bool replace}) {
    if (replace) {
      _feedItems
        ..clear()
        ..addAll(incoming);
      return;
    }
    final existingIds = _feedItems.map((item) => item.id).toSet();
    _feedItems.addAll(incoming.where((item) => !existingIds.contains(item.id)));
  }

  void _prefetchNextPageIfNeeded() {
    if (_isLoadingMore || _hasReachedMax) return;
    if (_feedItems.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadMorePosts();
    });
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

    setState(() => _currentPostIndex = index);
    _feedVideoProgress.reset();

    final threshold =
        _feedItems.length <= HomeLayoutConstants.feedPrefetchMinPosts
        ? 0
        : _feedItems.length - HomeLayoutConstants.feedPrefetchThresholdOffset;
    if (index >= threshold) {
      _loadMorePosts();
    }
  }

  void _handlePostsState(BuildContext context, PostsState state) {
    final theme = Theme.of(context);

    if (state is FeedLoadSuccess) {
      final loadedPage = _feedPage;
      final countBefore = _feedItems.length;
      setState(() {
        _feedLoadFailed = false;
        _feedErrorMessage = null;
        if (loadedPage == 1) {
          _awaitingInitialFeed = false;
          _expectingFeedPage1 = false;
        }
        _mergeFeedItems(state.items, replace: loadedPage == 1);
        if (loadedPage == 1) {
          _currentPostIndex = 0;
        } else if (_currentPostIndex >= _feedItems.length) {
          _currentPostIndex = _feedItems.length - 1;
        }
        final added = _feedItems.length - countBefore;
        if (loadedPage > 1 && (state.items.isEmpty || added == 0)) {
          _hasReachedMax = true;
        } else {
          _hasReachedMax = state.hasReachedMax;
        }
        _isLoadingMore = false;
      });
      if (loadedPage == 1) {
        _completePullRefreshIfPending();
      }
      if (!_hasReachedMax) {
        _prefetchNextPageIfNeeded();
      }
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
            _feedPage = 1;
            _hasReachedMax = false;
          } else if (index > 0 && _pageController.hasClients) {
            _pageController.jumpToPage(index - 1);
          }
        }
      });
    } else if (state is PostHiddenFromFeedState) {
      setState(() {
        final index = _feedItems.indexWhere(
          (item) => item.post.id == state.postId,
        );
        if (index != -1) {
          _feedItems.removeAt(index);
          if (_feedItems.isEmpty) {
            _feedPage = 1;
            _hasReachedMax = false;
          } else if (_pageController.hasClients) {
            final next = index.clamp(0, _feedItems.length - 1);
            _currentPostIndex = next;
            _pageController.jumpToPage(next);
          }
        }
      });
    } else if (state is PostsFailure) {
      // Ignore unrelated PostsBloc failures (likes, stories, profile grids, etc.).
      final isFeedPage1Failure =
          _expectingFeedPage1 && state.profileLoadKey == null;
      setState(() {
        if (isFeedPage1Failure) {
          _awaitingInitialFeed = false;
          _expectingFeedPage1 = false;
          if (_feedItems.isEmpty) {
            _feedLoadFailed = true;
            _feedErrorMessage = state.message;
          }
        }
        if (_isLoadingMore && _feedPage > 1) {
          _feedPage--;
        }
        _isLoadingMore = false;
      });
      if (isFeedPage1Failure) {
        _completePullRefreshIfPending();
      }
      // Prefer in-place retry UI when the feed is empty; snackbar when content remains.
      if (isFeedPage1Failure && _feedItems.isNotEmpty) {
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
          child: FeedTopBar(
            selectedTab: _selectedFeedTab,
            onTabChanged: _onFeedTabChanged,
            onLiveTap: () => context.pushFromFeed('lives'),
            onSearchTap: () => context.pushFromFeed('posts_search'),
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
