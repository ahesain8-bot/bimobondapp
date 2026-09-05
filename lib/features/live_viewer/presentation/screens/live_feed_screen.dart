import 'dart:async';
import 'package:bimobondapp/l10n/app_localizations.dart';
import '../../domain/entities/live_feed_activation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/live_feed_refresh_bus.dart';
import '../../../live/presentation/utils/live_screen_wakelock.dart';
import '../bloc/live_feed/live_feed_bloc.dart';
import '../bloc/live_feed/live_feed_event.dart';
import '../bloc/live_feed/live_feed_state.dart';
import '../bloc/live_viewer/live_viewer_bloc.dart';
import '../bloc/live_viewer/live_viewer_event.dart';
import '../di/live_viewer_injector.dart' as di;
import '../widgets/live_room_page.dart';
import '../widgets/live_stories_strip.dart';
import '../../domain/entities/live_entity.dart';
import 'package:bimobondapp/features/live_viewer/core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// TikTok LIVE Discover: stories strip on top + finite vertical swipe feed.
///
/// Discovery stays metadata-only in [LiveFeedBloc]. LiveKit / Socket.IO
/// connect only for the active page via [LiveViewerBloc].
class LiveFeedScreen extends StatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedViewState();
}

class _LiveFeedViewState extends State<LiveFeedScreen>
    with WidgetsBindingObserver {
  late final LiveFeedBloc _feedBloc;
  late final LiveViewerBloc _viewerBloc;
  late final PageController _pageController;
  final ValueNotifier<int> _currentIndex = ValueNotifier<int>(0);

  /// 1 = Discover + stories fully visible above the live (TikTok start state).
  /// 0 = live edge-to-edge (after vertical swipe). Tracks the swipe so the
  /// header collapses in sync with the page, matching the reference video.
  final ValueNotifier<double> _discoverFactor = ValueNotifier<double>(1);
  var _userDraggingFeed = false;

  /// Story taps jump pages without entering fullscreen Discover collapse.
  var _storyJumpInProgress = false;
  Timer? _refreshTimer;
  var _refreshInFlight = false;
  var _isExiting = false;
  LiveFeedActivation? _activation;
  String? _entryKey;

  void _activate(LiveEntity live) {
    if (_entryKey != live.feedEntryKey) {
      _entryKey = live.feedEntryKey;
      _activation = LiveFeedActivation.fromEntry(live);
    }
    _viewerBloc.add(LiveViewerActivated(live, activation: _activation));
  }

  static const double _storiesStripH = 104;
  static const double _discoverTitleH = 48;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feedBloc = di.sl<LiveFeedBloc>();
    _viewerBloc = di.sl<LiveViewerBloc>();
    _pageController = PageController()..addListener(_onPageOffset);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    LiveScreenWakelock.enable();
    Future.microtask(() {
      // Uses the repository TTL cache — reopening Lives does not re-hit
      // the network when a fresh page-1 response is already available.
      _feedBloc.add(const LiveFeedLoadRequested(refresh: true));
    });

    LiveFeedRefreshBus.instance.addListener(_onLiveEndedSignal);

    // Was 8s and stacked with every reopen → "Too many requests" on feed.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _silentRefresh(),
    );
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _refreshInFlight) return;
    _feedBloc.add(const LiveFeedSilentRefreshRequested());
  }

  void _onLiveEndedSignal() {
    if (!mounted) return;
    final endedId = LiveFeedRefreshBus.instance.lastEndedLiveId;
    if (endedId == null) return;
    _feedBloc.add(LiveFeedLiveRemoved(endedId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isExiting) return;
    if (state == AppLifecycleState.resumed) {
      LiveScreenWakelock.enable();
      final lives = _feedBloc.state.lives;
      if (lives.isNotEmpty) {
        final index = _currentIndex.value.clamp(0, lives.length - 1);
        _activate(lives[index]);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _viewerBloc.add(const LiveViewerDeactivated());
      LiveScreenWakelock.disable();
    }
  }

  @override
  void dispose() {
    _isExiting = true;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    LiveFeedRefreshBus.instance.removeListener(_onLiveEndedSignal);
    _viewerBloc.add(const LiveViewerDeactivated(leavingFeed: true));
    _pageController.removeListener(_onPageOffset);
    _pageController.dispose();
    _currentIndex.dispose();
    _discoverFactor.dispose();
    _feedBloc.close();
    unawaited(_viewerBloc.close());
    LiveScreenWakelock.disable();
    super.dispose();
  }

  void _onPageOffset() {
    if (!_userDraggingFeed || !_pageController.hasClients) return;
    final page = _pageController.page ?? 0;
    final liveCount = _feedBloc.state.lives.length;

    // Single-live feed has no next page — collapse is handled via drag delta.
    if (liveCount <= 1) return;

    // At / near the top page: keep Discover visible (never fullscreen here).
    if (page <= 0.05) {
      _discoverFactor.value = 1;
      return;
    }

    // Between page 0 and 1: collapse stories in sync with the swipe.
    if (page <= 1.0) {
      _discoverFactor.value = (1.0 - page).clamp(0.0, 1.0);
    } else {
      _discoverFactor.value = 0;
    }
  }

  void _showDiscover() {
    if (_discoverFactor.value != 1) {
      _discoverFactor.value = 1;
    }
  }

  void _hideDiscover() {
    if (_discoverFactor.value != 0) {
      _discoverFactor.value = 0;
    }
  }

  void _enterFullscreen() {
    _hideDiscover();
  }

  /// One-live (or last-page) upward drag: collapse Discover without a next page.
  void _applySingleLiveDrag(DragUpdateDetails details) {
    final dy = details.delta.dy;
    if (dy == 0) return;
    // Swipe up (negative dy) → hide stories; swipe down → show them.
    final next = (_discoverFactor.value + dy / 220).clamp(0.0, 1.0);
    if (next != _discoverFactor.value) {
      _discoverFactor.value = next;
    }
  }

  void _settleDiscoverAfterDrag() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? 0;
    final index = _currentIndex.value;
    final liveCount = _feedBloc.state.lives.length;

    // Single live: snap to fullscreen or Discover from drag progress.
    if (liveCount <= 1) {
      if (_discoverFactor.value < 0.55) {
        _hideDiscover();
      } else {
        _showDiscover();
      }
      return;
    }

    // Scrolled to top → Discover + stories, not fullscreen.
    if (index == 0) {
      _showDiscover();
      if (page > 0.02) {
        unawaited(
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          ),
        );
      }
      return;
    }

    // Past the first live → immersive fullscreen (stories hidden).
    _hideDiscover();
  }

  bool _onFeedScrollNotification(ScrollNotification notification) {
    final liveCount = _feedBloc.state.lives.length;
    final singleLive = liveCount <= 1;

    switch (notification) {
      case ScrollStartNotification(:final dragDetails) when dragDetails != null:
        _userDraggingFeed = true;
      case ScrollUpdateNotification(:final dragDetails)
          when dragDetails != null:
        _userDraggingFeed = true;
        if (singleLive) {
          _applySingleLiveDrag(dragDetails);
        } else {
          _onPageOffset();
        }
      case ScrollEndNotification():
        if (_userDraggingFeed) {
          _userDraggingFeed = false;
          _settleDiscoverAfterDrag();
        }
      case OverscrollNotification(:final overscroll):
        if (_currentIndex.value == 0 && overscroll < -2) {
          // Pull down → Discover + stories.
          _showDiscover();
        } else if (singleLive &&
            overscroll > 4 &&
            _discoverFactor.value > 0.4) {
          // Swipe up with only one live → fullscreen.
          _enterFullscreen();
        }
      default:
        break;
    }
    return false;
  }

  void _onPageChanged(int index) {
    if (_isExiting) return;
    final feed = _feedBloc.state;
    final lives = feed.lives;
    if (lives.isEmpty) return;

    final clamped = index.clamp(0, lives.length - 1);
    _currentIndex.value = clamped;

    if (_storyJumpInProgress) {
      _storyJumpInProgress = false;
      // Stay in Discover layout after tapping a story avatar.
      _showDiscover();
    } else if (clamped == 0) {
      // Multi-live: returning to the first page restores Discover.
      // Single-live: keep fullscreen if the user already entered it.
      if (lives.length > 1) {
        _showDiscover();
      }
    } else if (!_userDraggingFeed) {
      _hideDiscover();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isExiting) return;
      final latest = _feedBloc.state;
      final rooms = latest.lives;
      if (rooms.isEmpty) return;
      final i = _currentIndex.value.clamp(0, rooms.length - 1);

      if (i >= rooms.length - 2 && latest.hasMore && !latest.isLoadingMore) {
        _feedBloc.add(const LiveFeedLoadMoreRequested());
      }

      _activate(rooms[i]);
    });
  }

  void _onStoryTap(int index) {
    if (_isExiting) return;
    final lives = _feedBloc.state.lives;
    if (index < 0 || index >= lives.length) return;
    if (index == _currentIndex.value) return;
    // Story taps only switch the live under Discover — never force fullscreen.
    _storyJumpInProgress = true;
    _showDiscover();
    _currentIndex.value = index;
    _pageController.jumpToPage(index);
    _activate(lives[index]);
  }

  void _onGoLive() {
    context.pushNamed('add_post_camera');
  }

  Future<void> _refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      _feedBloc.add(const LiveFeedRefreshRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      final lives = _feedBloc.state.lives;
      if (lives.isNotEmpty) {
        _pageController.jumpToPage(0);
        _currentIndex.value = 0;
        _discoverFactor.value = 1;
        _activate(lives.first);
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> _closeDiscover() async {
    if (_isExiting) return;
    _isExiting = true;
    _refreshTimer?.cancel();
    LiveScreenWakelock.disable();
    _viewerBloc.add(const LiveViewerDeactivated(leavingFeed: true));
    await _viewerBloc.waitForIdle();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _exitLiveFeed() => unawaited(_closeDiscover());

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LiveFeedBloc>.value(value: _feedBloc),
        BlocProvider<LiveViewerBloc>.value(value: _viewerBloc),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<LiveFeedBloc, LiveFeedState>(
            listenWhen: (prev, next) {
              if (prev.lives.length == next.lives.length) return false;
              return true;
            },
            listener: (context, next) {
              if (_isExiting || next.lives.isEmpty) return;
              if (_viewerBloc.activeLiveId == null ||
                  !next.lives.any((l) => l.id == _viewerBloc.activeLiveId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || _isExiting) return;
                  final lives = _feedBloc.state.lives;
                  if (lives.isEmpty) return;
                  final target = _currentIndex.value.clamp(0, lives.length - 1);
                  if (_currentIndex.value != target) {
                    _pageController.jumpToPage(target);
                    _currentIndex.value = target;
                  }
                  _activate(lives[target]);
                });
              }
            },
          ),
        ],
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || _isExiting) return;
            unawaited(_closeDiscover());
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: BlocBuilder<LiveFeedBloc, LiveFeedState>(
              buildWhen: (prev, next) =>
                  prev.isLoading != next.isLoading ||
                  prev.isLoadingMore != next.isLoadingMore ||
                  prev.hasMore != next.hasMore ||
                  prev.error != next.error ||
                  !_sameRooms(prev.lives, next.lives),
              builder: (context, feed) {
                return ValueListenableBuilder<int>(
                  valueListenable: _currentIndex,
                  builder: (context, currentIndex, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: _discoverFactor,
                      builder: (context, discoverFactor, _) {
                        return _buildBody(feed, currentIndex, discoverFactor);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static bool _sameRooms(List<LiveEntity> a, List<LiveEntity> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Widget _buildBody(
    LiveFeedState feed,
    int currentIndex,
    double discoverFactor,
  ) {
    if (feed.isLoading && feed.lives.isEmpty) {
      return _LoadingSkeleton();
    }

    if (feed.error != null && feed.lives.isEmpty) {
      return Column(
        children: [
          _DiscoverHeader(onClose: _exitLiveFeed),
          Expanded(
            child: _ErrorView(error: feed.error!, onRetry: _refresh),
          ),
        ],
      );
    }

    if (feed.lives.isEmpty) {
      return Column(
        children: [
          _DiscoverHeader(onClose: _exitLiveFeed),
          Expanded(child: _EmptyView(onRefresh: _refresh)),
        ],
      );
    }

    final selected = currentIndex.clamp(0, feed.lives.length - 1);
    final topPad = MediaQuery.paddingOf(context).top;
    final discoverH = topPad + _discoverTitleH + _storiesStripH;
    final showDiscover = discoverFactor > 0.001;

    final feedView = NotificationListener<ScrollNotification>(
      onNotification: _onFeedScrollNotification,
      child: RefreshIndicator(
        // Pull-to-refresh only while Discover is open (matches TikTok start).
        notificationPredicate: (_) => discoverFactor > 0.95,
        color: AppColors.secondary,
        backgroundColor: Colors.black,
        onRefresh: () async {
          await _refresh();
        },
        displacement: 60,
        strokeWidth: 2.5,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          allowImplicitScrolling: false,
          physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: feed.lives.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final live = feed.lives[index];
            return Stack(
              key: ValueKey(live.feedEntryKey),
              fit: StackFit.expand,
              children: [
                LiveRoomPage(
                  live: live,
                  isActive: index == selected,
                  onClose: _exitLiveFeed,
                ),
                if (live.isPromoted)
                  PositionedDirectional(
                    start: 16,
                    top: 94,
                    child: SafeArea(
                      child: IgnorePointer(
                        child: Chip(
                          avatar: const Icon(Icons.campaign_outlined, size: 18),
                          label: Text(
                            AppLocalizations.of(
                              context,
                            )!.livePromotionPromotedLabel,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    // TikTok Discover: stories sit ABOVE the live. Vertical swipe collapses
    // them in sync with the page offset until the live is fullscreen.
    return Column(
      children: [
        if (showDiscover)
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: discoverFactor.clamp(0.0, 1.0),
              child: SizedBox(
                height: discoverH,
                width: double.infinity,
                child: ColoredBox(
                  color: Colors.black,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DiscoverHeader(onClose: _exitLiveFeed),
                      LiveStoriesStrip(
                        lives: feed.lives,
                        selectedIndex: selected,
                        isLoadingMore: feed.isLoadingMore,
                        onLiveTap: _onStoryTap,
                        onGoLiveTap: _onGoLive,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              feedView,
              if (discoverFactor > 0.85 && selected == 0)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _enterFullscreen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              if (feed.isLoadingMore)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, top + 4, 8, 4),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.textPrimary,
              ),
              tooltip: 'Events',
            ),
            const Expanded(
              child: Text(
                'Discover',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1A1A1A),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(color: Colors.black),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Failure error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isAuth =
        error is AuthorizationFailure || error is AuthenticationFailure;
    final isNetwork = error is NetworkFailure;
    final icon = isNetwork
        ? Icons.wifi_off_outlined
        : isAuth
        ? Icons.lock_outline
        : Icons.error_outline;
    final title = isNetwork
        ? 'Can\u2019t connect'
        : isAuth
        ? 'Please sign in'
        : 'Couldn\u2019t load LIVE';
    final cta = isAuth ? 'Sign in' : 'Retry';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.error, size: 56),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: Text(cta)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.live_tv_outlined,
            size: 72,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          const Text(
            'No lives right now',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRefresh, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
