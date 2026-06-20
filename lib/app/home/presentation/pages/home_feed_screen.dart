import 'dart:async';

import 'package:bimobondapp/app/auth/presentation/bloc/auth_bloc.dart';
import 'package:bimobondapp/app/auth/presentation/bloc/auth_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_empty_state.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/feed_video_progress_notifier.dart';
import 'package:bimobondapp/app/home/presentation/widgets/home_feed/home_feed_stack.dart';
import 'package:bimobondapp/app/auth/presentation/di/auth_injector.dart' as auth_di;
import 'package:bimobondapp/core/data/user_location_store.dart';
import 'package:bimobondapp/app/posts/domain/entities/feed_item_entity.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_bloc.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_event.dart';
import 'package:bimobondapp/app/posts/presentation/bloc/posts_state.dart';
import 'package:bimobondapp/core/constants/home_layout_constants.dart';
import 'package:bimobondapp/core/theme/feed_overlay_theme.dart';
import 'package:bimobondapp/core/widgets/skeleton_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class HomeFeedScreen extends StatefulWidget {
  final bool isTabActive;

  const HomeFeedScreen({super.key, this.isTabActive = true});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  final PageController _pageController = PageController();
  final List<FeedItemEntity> _feedItems = [];
  int _feedPage = 1;
  bool _hasReachedMax = false;
  bool _isLoadingMore = false;
  int _currentPostIndex = 0;
  bool _awaitingInitialFeed = true;
  Completer<void>? _pullRefreshCompleter;
  final FeedVideoProgressNotifier _feedVideoProgress =
      FeedVideoProgressNotifier();

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
      _loadTabData();
    } else if (!widget.isTabActive && oldWidget.isTabActive) {
      _feedVideoProgress.reset();
    }
  }

  void _loadTabData() {
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
    } else if (_hasReachedMax) {
      return;
    }

    final locationStore = auth_di.sl<UserLocationStore>();

    context.read<PostsBloc>().add(
      FetchFeedRequestedEvent(
        page: _feedPage,
        limit: HomeLayoutConstants.feedPageSize,
        isRefresh: refresh,
        isStory: false,
        sort: 'RANKED',
        latitude: locationStore.latitude,
        longitude: locationStore.longitude,
        radiusKm: 50,
      ),
    );
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
        if (loadedPage == 1) {
          _awaitingInitialFeed = false;
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
    } else if (state is PostsFailure) {
      setState(() {
        if (_feedPage == 1) {
          _awaitingInitialFeed = false;
        }
        if (_isLoadingMore && _feedPage > 1) {
          _feedPage--;
        }
        _isLoadingMore = false;
      });
      if (_feedPage == 1) {
        _completePullRefreshIfPending();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
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
                _feedItems.isEmpty &&
                (state is PostsLoading ||
                    state is PostsInitial ||
                    _awaitingInitialFeed);

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
              return wrapRefresh(const FeedSkeleton());
            }

            if (_feedItems.isEmpty) {
              return wrapRefresh(const FeedEmptyState());
            }

            return RefreshIndicator(
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
                  onLiveTap: () => context.pushNamed('lives'),
                  onSearchTap: () => context.pushNamed('posts_search'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
